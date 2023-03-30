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
  worker->used_buffers = malloc(sizeof(int64_t) * configuration->buffers_count);

  for (size_t index = 0; index < configuration->buffers_count; index++)
  {
    if (posix_memalign(&worker->buffers[index].iov_base, getpagesize(), configuration->buffer_size))
    {
      free(worker);
      return NULL;
    }
    worker->buffers[index].iov_len = configuration->buffer_size;
    worker->used_buffers[index] = TRANSPORT_BUFFER_AVAILABLE;
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

int transport_worker_select_buffer(transport_worker_t *worker)
{
  int buffer_id = 0;
  while (worker->used_buffers[buffer_id] != TRANSPORT_BUFFER_AVAILABLE)
  {
    if (++buffer_id == worker->buffers_count)
    {
      return -1;
    }
  }

  worker->used_buffers[buffer_id] = TRANSPORT_BUFFER_USED;
  return buffer_id;
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

int transport_worker_write(transport_worker_t *worker, uint32_t fd, uint16_t buffer_id, uint32_t offset, uint16_t event)
{
  struct io_uring *ring = worker->ring;
  struct io_uring_sqe *sqe = provide_sqe(ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  worker->used_buffers[buffer_id] = offset;
  uint64_t data = (((uint64_t)(fd) << 32) | (uint64_t)(buffer_id) << 16) | ((uint64_t)event);
  io_uring_prep_write_fixed(sqe, fd, worker->buffers[buffer_id].iov_base, worker->buffers[buffer_id].iov_len, offset, buffer_id);
  sqe->flags |= IOSQE_IO_LINK | IOSQE_IO_HARDLINK;
  io_uring_sqe_set_data64(sqe, data);
  sqe = provide_sqe(ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, (int32_t)worker->id, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  return io_uring_submit(ring);
}

int transport_worker_read(transport_worker_t *worker, uint32_t fd, uint16_t buffer_id, uint32_t offset, uint16_t event)
{
  struct io_uring *ring = worker->ring;
  struct io_uring_sqe *sqe = provide_sqe(ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  worker->used_buffers[buffer_id] = offset;
  uint64_t data = (((uint64_t)(fd) << 32) | (uint64_t)(buffer_id) << 16) | ((uint64_t)event);
  io_uring_prep_read_fixed(sqe, fd, worker->buffers[buffer_id].iov_base, worker->buffers[buffer_id].iov_len, offset, buffer_id);
  sqe->flags |= IOSQE_IO_LINK | IOSQE_IO_HARDLINK;
  io_uring_sqe_set_data64(sqe, data);
  sqe = provide_sqe(ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, (int32_t)worker->id, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  return io_uring_submit(ring);
}

int transport_worker_send_message(transport_worker_t *worker, uint32_t fd, uint16_t buffer_id, struct sockaddr_in address, socklen_t address_length, int message_flags, uint16_t event)
{
  struct io_uring *ring = worker->ring;
  struct io_uring_sqe *sqe = provide_sqe(ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  worker->used_buffers[buffer_id] = 0;
  uint64_t data = (((uint64_t)(fd) << 32) | (uint64_t)(buffer_id) << 16) | ((uint64_t)event);
  struct msghdr message;
  memset(&message, 0, sizeof(message));
  message.msg_name = &address;
  message.msg_namelen = address_length;
  message.msg_iov = &worker->buffers[buffer_id];
  message.msg_iovlen = 1;
  io_uring_prep_sendmsg(sqe, fd, &message, message_flags);
  sqe->flags |= IOSQE_IO_LINK | IOSQE_IO_HARDLINK;
  io_uring_sqe_set_data64(sqe, data);
  sqe = provide_sqe(ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, (int32_t)worker->id, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  return io_uring_submit(ring);
}

int transport_worker_receive_message(transport_worker_t *worker, uint32_t fd, uint16_t buffer_id, struct sockaddr_in address, socklen_t address_length, int message_flags, uint16_t event)
{
  struct io_uring *ring = worker->ring;
  struct io_uring_sqe *sqe = provide_sqe(ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  worker->used_buffers[buffer_id] = 0;
  uint64_t data = (((uint64_t)(fd) << 32) | (uint64_t)(buffer_id) << 16) | ((uint64_t)event);
  struct msghdr message;
  memset(&message, 0, sizeof(message));
  message.msg_name = &address;
  message.msg_namelen = address_length;
  message.msg_iov = &worker->buffers[buffer_id];
  message.msg_iovlen = 1;
  io_uring_prep_recvmsg(sqe, fd, &message, message_flags);
  sqe->flags |= IOSQE_IO_LINK | IOSQE_IO_HARDLINK;
  io_uring_sqe_set_data64(sqe, data);
  sqe = provide_sqe(ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, (int32_t)worker->id, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  return io_uring_submit(ring);
}

int transport_worker_connect(transport_worker_t *worker, transport_client_t *client)
{
  struct io_uring *ring = worker->ring;
  struct io_uring_sqe *sqe = provide_sqe(ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  uint64_t data = ((uint64_t)(client->fd) << 32) | ((uint64_t)TRANSPORT_EVENT_CONNECT);
  io_uring_prep_connect(sqe, client->fd, (struct sockaddr *)&client->inet_client_address, client->client_address_length);
  sqe->flags |= IOSQE_IO_LINK | IOSQE_IO_HARDLINK;
  io_uring_sqe_set_data64(sqe, data);
  sqe = provide_sqe(ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, (int32_t)worker->id, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  return io_uring_submit(ring);
}

int transport_worker_accept(transport_worker_t *worker, transport_server_t *server)
{
  struct io_uring *ring = worker->ring;
  struct io_uring_sqe *sqe = provide_sqe(ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  uint64_t data = ((uint64_t)(server->fd) << 32) | ((uint64_t)TRANSPORT_EVENT_ACCEPT);
  io_uring_prep_accept(sqe, server->fd, (struct sockaddr *)&server->inet_server_address, &server->server_address_length, 0);
  sqe->flags |= IOSQE_IO_LINK | IOSQE_IO_HARDLINK;
  io_uring_sqe_set_data64(sqe, data);
  sqe = provide_sqe(ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, (int32_t)worker->id, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  return io_uring_submit(ring);
}

void transport_worker_reuse_buffer(transport_worker_t *worker, uint16_t buffer_id)
{
  struct iovec buffer = worker->buffers[buffer_id];
  memset(buffer.iov_base, 0, worker->buffer_size);
  buffer.iov_len = worker->buffer_size;
  worker->used_buffers[buffer_id] = 0;
}

void transport_worker_free_buffer(transport_worker_t *worker, uint16_t buffer_id)
{
  struct iovec buffer = worker->buffers[buffer_id];
  memset(buffer.iov_base, 0, worker->buffer_size);
  buffer.iov_len = worker->buffer_size;
  worker->used_buffers[buffer_id] = TRANSPORT_BUFFER_AVAILABLE;
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

void transport_worker_destroy(transport_worker_t *worker)
{
  io_uring_queue_exit(worker->ring);
  for (size_t index = 0; index < worker->buffers_count; index++)
  {
    free(worker->buffers[index].iov_base);
  }
  free(worker->buffers);
  free(worker->used_buffers);
  free(worker->ring);
  free(worker);
}