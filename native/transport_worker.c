#include "transport_common.h"
#include "transport_worker.h"
#include "transport_constants.h"

transport_worker_t *transport_worker_initialize(transport_worker_configuration_t *configuration, uint8_t id)
{
  transport_worker_t *worker = malloc(sizeof(transport_worker_t));
  if (!worker)
  {
    return NULL;
  }

  worker->id = id;
  worker->listeners = transport_listener_pool_initialize();
  worker->buffer_size = configuration->buffer_size;
  worker->buffers_count = configuration->buffers_count;
  worker->buffers = malloc(sizeof(struct iovec) * configuration->buffers_count);
  worker->events = mh_events_new();

  if (transport_buffers_pool_create(&worker->free_buffers, configuration->buffers_count))
  {
    free(worker);
    return NULL;
  }

  worker->inet_used_messages = malloc(sizeof(struct msghdr) * configuration->buffers_count);
  worker->unix_used_messages = malloc(sizeof(struct msghdr) * configuration->buffers_count);

  for (size_t index = 0; index < configuration->buffers_count; index++)
  {
    if (posix_memalign(&worker->buffers[index].iov_base, getpagesize(), configuration->buffer_size))
    {
      free(worker);
      return NULL;
    }
    worker->buffers[index].iov_len = configuration->buffer_size;

    memset(&worker->inet_used_messages[index], 0, sizeof(struct msghdr));
    worker->inet_used_messages[index].msg_name = malloc(sizeof(struct sockaddr_in));
    worker->inet_used_messages[index].msg_namelen = sizeof(struct sockaddr_in);

    memset(&worker->unix_used_messages[index], 0, sizeof(struct msghdr));
    worker->unix_used_messages[index].msg_name = malloc(sizeof(struct sockaddr_un));
    worker->unix_used_messages[index].msg_namelen = sizeof(struct sockaddr_un);

    transport_buffers_pool_push(&worker->free_buffers, index);
  }
  worker->ring = malloc(sizeof(struct io_uring));
  int32_t status = io_uring_queue_init(configuration->ring_size, worker->ring, configuration->ring_flags);
  if (status)
  {
    free(worker->ring);
    free(worker);
    return NULL;
  }

  status = io_uring_register_buffers(worker->ring, worker->buffers, worker->buffers_count);
  if (status)
  {
    free(worker->ring);
    free(worker);
    return NULL;
  }

  return worker;
}

int32_t transport_worker_get_buffer(transport_worker_t *worker)
{
  return transport_buffers_pool_pop(&worker->free_buffers);
}

static inline transport_listener_t *transport_listener_pool_next(transport_listener_pool_t *pool)
{
  if (unlikely(!pool->next_listener))
  {
    pool->next_listener = pool->listeners.next;
    pool->next_listener_index = 0;
    return rlist_entry(pool->next_listener, transport_listener_t, listener_pool_link);
  }
  if (pool->next_listener_index + 1 == pool->count)
  {
    pool->next_listener = pool->listeners.next;
    pool->next_listener_index = 0;
    return rlist_entry(pool->next_listener, transport_listener_t, listener_pool_link);
  }
  pool->next_listener = pool->next_listener->next;
  pool->next_listener_index++;
  return rlist_entry(pool->next_listener, transport_listener_t, listener_pool_link);
}

static inline void transport_worker_add_event(transport_worker_t *worker, int fd, uint64_t data, int64_t timeout)
{
  struct mh_events_node_t node;
  node.data = data;
  node.timeout = timeout;
  node.timestamp = time(NULL);
  node.fd = fd;
  mh_events_put(worker->events, &node, NULL, 0);
}

void transport_worker_custom(transport_worker_t *worker, uint16_t callback_id, int64_t data)
{
  struct io_uring *ring = worker->ring;
  struct io_uring_sqe *sqe = provide_sqe(ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  int32_t result = (((int32_t)callback_id) << 16) | ((int32_t)TRANSPORT_EVENT_CUSTOM);
  io_uring_prep_msg_ring(sqe, worker->ring->ring_fd, result, data, 0);
  sqe->flags |= IOSQE_IO_HARDLINK | IOSQE_CQE_SKIP_SUCCESS;
  sqe = provide_sqe(ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, (int32_t)worker->id, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  io_uring_submit(ring);
}

void transport_worker_write(transport_worker_t *worker, uint32_t fd, uint16_t buffer_id, uint32_t offset, int64_t timeout, uint16_t event)
{
  struct io_uring *ring = worker->ring;
  struct io_uring_sqe *sqe = provide_sqe(ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  uint64_t data = (((uint64_t)(fd) << 32) | (uint64_t)(buffer_id) << 16) | ((uint64_t)event);
  io_uring_prep_write_fixed(sqe, fd, worker->buffers[buffer_id].iov_base, worker->buffers[buffer_id].iov_len, offset, buffer_id);
  sqe->flags |= IOSQE_IO_HARDLINK;
  io_uring_sqe_set_data64(sqe, data);
  sqe = provide_sqe(ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, (int32_t)worker->id, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  io_uring_submit(ring);
  transport_worker_add_event(worker, fd, data, TRANSPORT_TIMEOUT_INFINITY);
}

void transport_worker_read(transport_worker_t *worker, uint32_t fd, uint16_t buffer_id, uint32_t offset, int64_t timeout, uint16_t event)
{
  struct io_uring *ring = worker->ring;
  struct io_uring_sqe *sqe = provide_sqe(ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  uint64_t data = (((uint64_t)(fd) << 32) | (uint64_t)(buffer_id) << 16) | ((uint64_t)event);
  io_uring_prep_read_fixed(sqe, fd, worker->buffers[buffer_id].iov_base, worker->buffers[buffer_id].iov_len, offset, buffer_id);
  sqe->flags |= IOSQE_IO_HARDLINK;
  io_uring_sqe_set_data64(sqe, data);
  sqe = provide_sqe(ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, (int32_t)worker->id, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  io_uring_submit(ring);
  transport_worker_add_event(worker, fd, data, timeout);
}

void transport_worker_send_message(transport_worker_t *worker,
                                   uint32_t fd,
                                   uint16_t buffer_id,
                                   struct sockaddr *address,
                                   transport_socket_family_t socket_family,
                                   int message_flags,
                                   int64_t timeout,
                                   uint16_t event)
{
  struct io_uring *ring = worker->ring;
  struct io_uring_sqe *sqe = provide_sqe(ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  uint64_t data = (((uint64_t)(fd) << 32) | (uint64_t)(buffer_id) << 16) | ((uint64_t)event);
  struct msghdr *message;
  if (socket_family == INET)
  {
    message = &worker->inet_used_messages[buffer_id];
    memcpy(message->msg_name, address, message->msg_namelen);
  }
  if (socket_family == UNIX)
  {
    message = &worker->unix_used_messages[buffer_id];
    message->msg_namelen = SUN_LEN((struct sockaddr_un *)address);
    memcpy(message->msg_name, address, message->msg_namelen);
  }
  message->msg_control = NULL;
  message->msg_controllen = 0;
  message->msg_iov = &worker->buffers[buffer_id];
  message->msg_iovlen = 1;
  message->msg_flags = 0;
  io_uring_prep_sendmsg(sqe, fd, message, message_flags);
  sqe->flags |= IOSQE_IO_HARDLINK;
  io_uring_sqe_set_data64(sqe, data);
  sqe = provide_sqe(ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, (int32_t)worker->id, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  io_uring_submit(ring);
  transport_worker_add_event(worker, fd, data, timeout);
}

void transport_worker_respond_message(transport_worker_t *worker,
                                      uint32_t fd,
                                      uint16_t buffer_id,
                                      transport_socket_family_t socket_family,
                                      int message_flags,
                                      int64_t timeout,
                                      uint16_t event)
{
  struct io_uring *ring = worker->ring;
  struct io_uring_sqe *sqe = provide_sqe(ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  uint64_t data = (((uint64_t)(fd) << 32) | (uint64_t)(buffer_id) << 16) | ((uint64_t)event);
  struct msghdr *message;
  if (socket_family == INET)
  {
    message = &worker->inet_used_messages[buffer_id];
  }
  if (socket_family == UNIX)
  {
    message = &worker->unix_used_messages[buffer_id];
    message->msg_namelen = SUN_LEN((struct sockaddr_un *)message->msg_name);
  }
  message->msg_control = NULL;
  message->msg_controllen = 0;
  message->msg_iov = &worker->buffers[buffer_id];
  message->msg_iovlen = 1;
  message->msg_flags = 0;
  io_uring_prep_sendmsg(sqe, fd, message, message_flags);
  sqe->flags |= IOSQE_IO_HARDLINK;
  io_uring_sqe_set_data64(sqe, data);
  sqe = provide_sqe(ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, (int32_t)worker->id, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  io_uring_submit(ring);
  transport_worker_add_event(worker, fd, data, timeout);
}

void transport_worker_receive_message(transport_worker_t *worker,
                                      uint32_t fd,
                                      uint16_t buffer_id,
                                      transport_socket_family_t socket_family,
                                      int message_flags,
                                      int64_t timeout,
                                      uint16_t event)
{
  struct io_uring *ring = worker->ring;
  struct io_uring_sqe *sqe = provide_sqe(ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  uint64_t data = (((uint64_t)(fd) << 32) | (uint64_t)(buffer_id) << 16) | ((uint64_t)event);
  struct msghdr *message;
  if (socket_family == INET)
  {
    message = &worker->inet_used_messages[buffer_id];
    message->msg_namelen = sizeof(struct sockaddr_in);
  }
  if (socket_family == UNIX)
  {
    message = &worker->unix_used_messages[buffer_id];
    message->msg_namelen = sizeof(struct sockaddr_un);
  }
  message->msg_control = NULL;
  message->msg_controllen = 0;
  memset(message->msg_name, 0, message->msg_namelen);
  message->msg_iov = &worker->buffers[buffer_id];
  message->msg_iovlen = 1;
  message->msg_flags = 0;
  io_uring_prep_recvmsg(sqe, fd, message, message_flags);
  sqe->flags |= IOSQE_IO_HARDLINK;
  io_uring_sqe_set_data64(sqe, data);
  sqe = provide_sqe(ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, (int32_t)worker->id, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  io_uring_submit(ring);
  transport_worker_add_event(worker, fd, data, timeout);
}

void transport_worker_connect(transport_worker_t *worker, transport_client_t *client, int64_t timeout)
{
  struct io_uring *ring = worker->ring;
  struct io_uring_sqe *sqe = provide_sqe(ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  uint64_t data = ((uint64_t)(client->fd) << 32) | ((uint64_t)TRANSPORT_EVENT_CONNECT);
  io_uring_prep_connect(sqe, client->fd, client->family == INET ? (struct sockaddr *)&client->inet_destination_address : (struct sockaddr *)&client->unix_destination_address, client->client_address_length);
  sqe->flags |= IOSQE_IO_HARDLINK;
  io_uring_sqe_set_data64(sqe, data);
  sqe = provide_sqe(ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, (int32_t)worker->id, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  io_uring_submit(ring);
  transport_worker_add_event(worker, client->fd, data, timeout);
}

void transport_worker_accept(transport_worker_t *worker, transport_server_t *server)
{
  struct io_uring *ring = worker->ring;
  struct io_uring_sqe *sqe = provide_sqe(ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  uint64_t data = ((uint64_t)(server->fd) << 32) | ((uint64_t)TRANSPORT_EVENT_ACCEPT);
  io_uring_prep_accept(sqe, server->fd, server->family == INET ? (struct sockaddr *)&server->inet_server_address : (struct sockaddr *)&server->unix_server_address, &server->server_address_length, 0);
  sqe->flags |= IOSQE_IO_HARDLINK;
  io_uring_sqe_set_data64(sqe, data);
  sqe = provide_sqe(ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, (int32_t)worker->id, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  io_uring_submit(ring);
  transport_worker_add_event(worker, server->fd, data, TRANSPORT_TIMEOUT_INFINITY);
}

void transport_worker_reuse_buffer(transport_worker_t *worker, uint16_t buffer_id)
{
  struct iovec buffer = worker->buffers[buffer_id];
  memset(buffer.iov_base, 0, worker->buffer_size);
  buffer.iov_len = worker->buffer_size;
}

void transport_worker_release_buffer(transport_worker_t *worker, uint16_t buffer_id)
{
  struct iovec buffer = worker->buffers[buffer_id];
  memset(buffer.iov_base, 0, worker->buffer_size);
  buffer.iov_len = worker->buffer_size;
  transport_buffers_pool_push(&worker->free_buffers, buffer_id);
}

void transport_worker_cancel_by_fd(transport_worker_t *worker, int fd)
{
  mh_int_t index;
  mh_int_t to_delete[worker->events->size];
  int to_delete_count = 0;
  mh_foreach(worker->events, index)
  {
    struct mh_events_node_t *node = mh_events_node(worker->events, index);
    if (node->fd == fd)
    {
      struct io_uring *ring = worker->ring;
      struct io_uring_sqe *sqe = provide_sqe(ring);
      transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
      io_uring_prep_cancel(sqe, (void *)node->data, IORING_ASYNC_CANCEL_ALL);
      sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
      to_delete[to_delete_count++] = index;
    }
  }
  for (int index = 0; index < to_delete_count; index++)
  {
    mh_events_del(worker->events, to_delete[index], 0);
  }
  io_uring_submit(worker->ring);
}

int transport_worker_peek(uint32_t cqe_count, struct io_uring_cqe **cqes, struct io_uring *ring)
{
  int count = 0;
  if (unlikely(!(count = io_uring_peek_batch_cqe(ring, &cqes[0], cqe_count))))
  {
    return -1;
  }
  return count;
}

struct sockaddr *transport_worker_get_endpoint_address(transport_worker_t *worker, transport_socket_family_t socket_family, int buffer_id)
{
  return socket_family == INET ? (struct sockaddr *)worker->inet_used_messages[buffer_id].msg_name : (struct sockaddr *)worker->unix_used_messages[buffer_id].msg_name;
}

void transport_worker_check_event_timeouts(transport_worker_t *worker)
{
  mh_int_t index;
  mh_int_t to_delete[worker->events->size];
  int to_delete_count = 0;
  mh_foreach(worker->events, index)
  {
    struct mh_events_node_t *node = mh_events_node(worker->events, index);
    int64_t timeout = node->timeout;
    if (timeout == TRANSPORT_TIMEOUT_INFINITY)
    {
      continue;
    }
    uint64_t timestamp = node->timestamp;
    uint64_t data = node->data;
    time_t current_time = time(NULL);
    if (current_time - timestamp > timeout)
    {
      struct io_uring *ring = worker->ring;
      struct io_uring_sqe *sqe = provide_sqe(ring);
      transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
      io_uring_prep_cancel(sqe, (void *)data, IORING_ASYNC_CANCEL_ALL);
      sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
      to_delete[to_delete_count++] = index;
    }
  }
  for (int index = 0; index < to_delete_count; index++)
  {
    mh_events_del(worker->events, to_delete[index], 0);
  }
  io_uring_submit(worker->ring);
}

void transport_worker_remove_event(transport_worker_t *worker, uint64_t data)
{
  mh_int_t event;
  if ((event = mh_events_find(worker->events, data, 0)) != mh_end(worker->events))
  {
    mh_events_del(worker->events, event, 0);
  }
}

void transport_worker_destroy(transport_worker_t *worker)
{
  io_uring_queue_exit(worker->ring);
  for (size_t index = 0; index < worker->buffers_count; index++)
  {
    free(worker->buffers[index].iov_base);
    free(worker->inet_used_messages[index].msg_name);
    free(worker->unix_used_messages[index].msg_name);
  }
  transport_buffers_pool_destroy(&worker->free_buffers);
  mh_events_delete(worker->events);
  free(worker->buffers);
  free(worker->inet_used_messages);
  free(worker->unix_used_messages);
  free(worker->listeners);
  free(worker->ring);
  free(worker);
}