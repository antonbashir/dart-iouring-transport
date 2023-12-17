#include "transport_worker.h"
#include <unistd.h>
#include "transport_common.h"
#include "transport_constants.h"

int transport_worker_initialize(transport_worker_t* worker,
                                transport_worker_configuration_t* configuration,
                                uint8_t id)
{
    worker->id = id;
    worker->ring_size = configuration->ring_size;
    worker->delay_randomization_factor = configuration->delay_randomization_factor;
    worker->base_delay_micros = configuration->base_delay_micros;
    worker->max_delay_micros = configuration->max_delay_micros;
    worker->buffer_size = configuration->buffer_size;
    worker->buffers_count = configuration->buffers_count;
    worker->timeout_checker_period_millis = configuration->timeout_checker_period_millis;
    worker->cqes = malloc(sizeof(struct io_uring_cqe) * worker->ring_size);
    worker->buffers = malloc(sizeof(struct iovec) * configuration->buffers_count);
    worker->cqe_wait_timeout_millis = configuration->cqe_wait_timeout_millis;
    worker->cqe_wait_count = configuration->cqe_wait_count;
    worker->cqe_peek_count = configuration->cqe_peek_count;
    worker->trace = configuration->trace;
    if (!worker->buffers)
    {
        return -ENOMEM;
    }

    worker->events = mh_events_new();
    if (!worker->events)
    {
        return -ENOMEM;
    }
    mh_events_reserve(worker->events, worker->buffers_count, 0);

    int result = transport_buffers_pool_create(&worker->free_buffers, configuration->buffers_count);
    if (result == -1)
    {
        return -ENOMEM;
    }

    worker->inet_used_messages = malloc(sizeof(struct msghdr) * configuration->buffers_count);
    worker->unix_used_messages = malloc(sizeof(struct msghdr) * configuration->buffers_count);

    if (!worker->inet_used_messages || !worker->unix_used_messages)
    {
        return -ENOMEM;
    }

    for (size_t index = 0; index < configuration->buffers_count; index++)
    {
        if (posix_memalign(&worker->buffers[index].iov_base, getpagesize(), configuration->buffer_size))
        {
            return -ENOMEM;
        }
        memset(worker->buffers[index].iov_base, 0, configuration->buffer_size);
        worker->buffers[index].iov_len = configuration->buffer_size;

        memset(&worker->inet_used_messages[index], 0, sizeof(struct msghdr));
        worker->inet_used_messages[index].msg_name = malloc(sizeof(struct sockaddr_in));
        if (!worker->inet_used_messages[index].msg_name)
        {
            return -ENOMEM;
        }
        worker->inet_used_messages[index].msg_namelen = sizeof(struct sockaddr_in);

        memset(&worker->unix_used_messages[index], 0, sizeof(struct msghdr));
        worker->unix_used_messages[index].msg_name = malloc(sizeof(struct sockaddr_un));
        if (!worker->unix_used_messages[index].msg_name)
        {
            return -ENOMEM;
        }
        worker->unix_used_messages[index].msg_namelen = sizeof(struct sockaddr_un);

        transport_buffers_pool_push(&worker->free_buffers, index);
    }
    worker->ring = malloc(sizeof(struct io_uring));
    if (!worker->ring)
    {
        return -ENOMEM;
    }
    result = io_uring_queue_init(configuration->ring_size, worker->ring, configuration->ring_flags);
    if (result)
    {
        return result;
    }

    result = io_uring_register_buffers(worker->ring, worker->buffers, worker->buffers_count);
    if (result)
    {
        return result;
    }

    return 0;
}

int32_t transport_worker_get_buffer(transport_worker_t* worker)
{
    return transport_buffers_pool_pop(&worker->free_buffers);
}

int32_t transport_worker_available_buffers(transport_worker_t* worker)
{
    return worker->free_buffers.count;
}

int32_t transport_worker_used_buffers(transport_worker_t* worker)
{
    return worker->buffers_count - worker->free_buffers.count;
}

void transport_worker_release_buffer(transport_worker_t* worker, uint16_t buffer_id)
{
    struct iovec* buffer = &worker->buffers[buffer_id];
    memset(buffer->iov_base, 0, worker->buffer_size);
    buffer->iov_len = worker->buffer_size;
    transport_buffers_pool_push(&worker->free_buffers, buffer_id);
}

static inline void transport_worker_add_event(transport_worker_t* worker, int fd, uint64_t data, int64_t timeout)
{
    struct mh_events_node_t node = {
        .data = data,
        .timeout = timeout,
        .timestamp = time(NULL),
        .fd = fd,
    };
    mh_events_put(worker->events, &node, NULL, 0);
}

void transport_worker_write(transport_worker_t* worker,
                            uint32_t fd,
                            uint16_t buffer_id,
                            uint32_t offset,
                            int64_t timeout,
                            uint16_t event,
                            uint8_t sqe_flags)
{
    struct io_uring* ring = worker->ring;
    struct io_uring_sqe* sqe = transport_provide_sqe(ring);
    uint64_t data = (((uint64_t)(fd) << 32) | (uint64_t)(buffer_id) << 16) | ((uint64_t)event);
    struct iovec* buffer = &worker->buffers[buffer_id];
    io_uring_prep_write_fixed(sqe, fd, buffer->iov_base, buffer->iov_len, offset, buffer_id);
    io_uring_sqe_set_data64(sqe, data);
    sqe->flags |= sqe_flags;
    transport_worker_add_event(worker, fd, data, timeout);
}

void transport_worker_read(transport_worker_t* worker,
                           uint32_t fd,
                           uint16_t buffer_id,
                           uint32_t offset,
                           int64_t timeout,
                           uint16_t event,
                           uint8_t sqe_flags)
{
    struct io_uring* ring = worker->ring;
    struct io_uring_sqe* sqe = transport_provide_sqe(ring);
    uint64_t data = (((uint64_t)(fd) << 32) | (uint64_t)(buffer_id) << 16) | ((uint64_t)event);
    struct iovec* buffer = &worker->buffers[buffer_id];
    io_uring_prep_read_fixed(sqe, fd, buffer->iov_base, buffer->iov_len, offset, buffer_id);
    io_uring_sqe_set_data64(sqe, data);
    sqe->flags |= sqe_flags;
    transport_worker_add_event(worker, fd, data, timeout);
}

void transport_worker_send_message(transport_worker_t* worker,
                                   uint32_t fd,
                                   uint16_t buffer_id,
                                   struct sockaddr* address,
                                   transport_socket_family_t socket_family,
                                   int message_flags,
                                   int64_t timeout,
                                   uint16_t event,
                                   uint8_t sqe_flags)
{
    struct io_uring* ring = worker->ring;
    struct io_uring_sqe* sqe = transport_provide_sqe(ring);
    uint64_t data = (((uint64_t)(fd) << 32) | (uint64_t)(buffer_id) << 16) | ((uint64_t)event);
    struct msghdr* message;
    if (socket_family == INET)
    {
        message = &worker->inet_used_messages[buffer_id];
        memcpy(message->msg_name, address, message->msg_namelen);
    }
    if (socket_family == UNIX)
    {
        message = &worker->unix_used_messages[buffer_id];
        message->msg_namelen = SUN_LEN((struct sockaddr_un*)address);
        memcpy(message->msg_name, address, message->msg_namelen);
    }
    message->msg_control = NULL;
    message->msg_controllen = 0;
    message->msg_iov = &worker->buffers[buffer_id];
    message->msg_iovlen = 1;
    message->msg_flags = 0;
    io_uring_prep_sendmsg(sqe, fd, message, message_flags);
    io_uring_sqe_set_data64(sqe, data);
    sqe->flags |= sqe_flags;
    transport_worker_add_event(worker, fd, data, timeout);
}

void transport_worker_receive_message(transport_worker_t* worker,
                                      uint32_t fd,
                                      uint16_t buffer_id,
                                      transport_socket_family_t socket_family,
                                      int message_flags,
                                      int64_t timeout,
                                      uint16_t event,
                                      uint8_t sqe_flags)
{
    struct io_uring* ring = worker->ring;
    struct io_uring_sqe* sqe = transport_provide_sqe(ring);
    uint64_t data = (((uint64_t)(fd) << 32) | (uint64_t)(buffer_id) << 16) | ((uint64_t)event);
    struct msghdr* message;
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
    io_uring_sqe_set_data64(sqe, data);
    sqe->flags |= sqe_flags;
    transport_worker_add_event(worker, fd, data, timeout);
}

void transport_worker_connect(transport_worker_t* worker, transport_client_t* client, int64_t timeout)
{
    struct io_uring* ring = worker->ring;
    struct io_uring_sqe* sqe = transport_provide_sqe(ring);
    uint64_t data = ((uint64_t)(client->fd) << 32) | ((uint64_t)TRANSPORT_EVENT_CONNECT | (uint64_t)TRANSPORT_EVENT_CLIENT);
    struct sockaddr* address = client->family == INET
                                   ? (struct sockaddr*)&client->inet_destination_address
                                   : (struct sockaddr*)&client->unix_destination_address;
    io_uring_prep_connect(sqe, client->fd, address, client->client_address_length);
    io_uring_sqe_set_data64(sqe, data);
    transport_worker_add_event(worker, client->fd, data, timeout);
}

void transport_worker_accept(transport_worker_t* worker, transport_server_t* server)
{
    struct io_uring* ring = worker->ring;
    struct io_uring_sqe* sqe = transport_provide_sqe(ring);
    uint64_t data = ((uint64_t)(server->fd) << 32) | ((uint64_t)TRANSPORT_EVENT_ACCEPT | (uint64_t)TRANSPORT_EVENT_SERVER);
    struct sockaddr* address = server->family == INET
                                   ? (struct sockaddr*)&server->inet_server_address
                                   : (struct sockaddr*)&server->unix_server_address;
    io_uring_prep_accept(sqe, server->fd, address, &server->server_address_length, 0);
    io_uring_sqe_set_data64(sqe, data);
    transport_worker_add_event(worker, server->fd, data, TRANSPORT_TIMEOUT_INFINITY);
}

void transport_worker_cancel_by_fd(transport_worker_t* worker, int fd)
{
    mh_int_t index;
    mh_int_t to_delete[worker->events->size];
    int to_delete_count = 0;
    mh_foreach(worker->events, index)
    {
        struct mh_events_node_t* node = mh_events_node(worker->events, index);
        if (node->fd == fd)
        {
            struct io_uring* ring = worker->ring;
            struct io_uring_sqe* sqe = transport_provide_sqe(ring);
            io_uring_prep_cancel(sqe, (void*)node->data, IORING_ASYNC_CANCEL_ALL);
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

int transport_worker_peek(transport_worker_t* worker)
{
    struct __kernel_timespec timeout = {
        .tv_nsec = worker->cqe_wait_timeout_millis * 1e+6,
        .tv_sec = 0,
    };
    io_uring_submit_and_wait_timeout(worker->ring, &worker->cqes[0], worker->cqe_wait_count, &timeout, 0);
    return io_uring_peek_batch_cqe(worker->ring, &worker->cqes[0], worker->cqe_peek_count);
}

void transport_worker_check_event_timeouts(transport_worker_t* worker)
{
    mh_int_t index;
    mh_int_t to_delete[worker->events->size];
    int to_delete_count = 0;
    mh_foreach(worker->events, index)
    {
        struct mh_events_node_t* node = mh_events_node(worker->events, index);
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
            struct io_uring* ring = worker->ring;
            struct io_uring_sqe* sqe = transport_provide_sqe(ring);
            io_uring_prep_cancel(sqe, (void*)data, IORING_ASYNC_CANCEL_ALL);
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

void transport_worker_remove_event(transport_worker_t* worker, uint64_t data)
{
    mh_int_t event;
    if ((event = mh_events_find(worker->events, data, 0)) != mh_end(worker->events))
    {
        mh_events_del(worker->events, event, 0);
    }
}

struct sockaddr* transport_worker_get_datagram_address(transport_worker_t* worker, transport_socket_family_t socket_family, int buffer_id)
{
    return socket_family == INET ? (struct sockaddr*)worker->inet_used_messages[buffer_id].msg_name
                                 : (struct sockaddr*)worker->unix_used_messages[buffer_id].msg_name;
}

void transport_worker_destroy(transport_worker_t* worker)
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
    free(worker->cqes);
    free(worker->buffers);
    free(worker->inet_used_messages);
    free(worker->unix_used_messages);
    free(worker->ring);
    free(worker);
}