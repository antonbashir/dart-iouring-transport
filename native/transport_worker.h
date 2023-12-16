#ifndef TRANSPORT_WORKER_H
#define TRANSPORT_WORKER_H

#include <stdint.h>
#include <stdio.h>
#include "transport_buffers_pool.h"
#include "transport_client.h"
#include "transport_collections.h"
#include "transport_server.h"

#if defined(__cplusplus)
extern "C"
{
#endif
    typedef struct transport_worker_configuration
    {
        uint16_t buffers_count;
        uint32_t buffer_size;
        size_t ring_size;
        unsigned int ring_flags;
        uint64_t timeout_checker_period_millis;
        uint32_t base_delay_micros;
        double delay_randomization_factor;
        uint64_t max_delay_micros;
        uint64_t cqe_wait_timeout_millis;
        uint32_t cqe_wait_count;
        uint32_t cqe_peek_count;
        bool trace;
    } transport_worker_configuration_t;

    typedef struct transport_worker
    {
        uint8_t id;
        struct transport_buffers_pool free_buffers;
        struct io_uring* ring;
        struct iovec* buffers;
        uint32_t buffer_size;
        uint16_t buffers_count;
        uint64_t timeout_checker_period_millis;
        uint32_t base_delay_micros;
        double delay_randomization_factor;
        uint64_t max_delay_micros;
        struct msghdr* inet_used_messages;
        struct msghdr* unix_used_messages;
        struct mh_events_t* events;
        size_t ring_size;
        int ring_flags;
        struct io_uring_cqe** cqes;
        uint64_t cqe_wait_timeout_millis;
        uint32_t cqe_wait_count;
        uint32_t cqe_peek_count;
        bool trace;
    } transport_worker_t;

    int transport_worker_initialize(transport_worker_t* worker,
                                    transport_worker_configuration_t* configuration,
                                    uint8_t id);

    void transport_worker_write(transport_worker_t* worker,
                                uint32_t fd,
                                uint16_t buffer_id,
                                uint32_t offset,
                                int64_t timeout,
                                uint16_t event,
                                uint8_t sqe_flags);
    void transport_worker_read(transport_worker_t* worker,
                               uint32_t fd,
                               uint16_t buffer_id,
                               uint32_t offset,
                               int64_t timeout,
                               uint16_t event,
                               uint8_t sqe_flags);
    void transport_worker_send_message(transport_worker_t* worker,
                                       uint32_t fd,
                                       uint16_t buffer_id,
                                       struct sockaddr* address,
                                       transport_socket_family_t socket_family,
                                       int message_flags,
                                       int64_t timeout,
                                       uint16_t event,
                                       uint8_t sqe_flags);
    void transport_worker_receive_message(transport_worker_t* worker,
                                          uint32_t fd,
                                          uint16_t buffer_id,
                                          transport_socket_family_t socket_family,
                                          int message_flags,
                                          int64_t timeout,
                                          uint16_t event,
                                          uint8_t sqe_flags);
    void transport_worker_connect(transport_worker_t* worker, transport_client_t* client, int64_t timeout);
    void transport_worker_accept(transport_worker_t* worker, transport_server_t* server);

    void transport_worker_cancel_by_fd(transport_worker_t* worker, int fd);

    void transport_worker_check_event_timeouts(transport_worker_t* worker);
    void transport_worker_remove_event(transport_worker_t* worker, uint64_t data);

    int32_t transport_worker_get_buffer(transport_worker_t* worker);
    void transport_worker_release_buffer(transport_worker_t* worker, uint16_t buffer_id);
    int32_t transport_worker_available_buffers(transport_worker_t* worker);
    int32_t transport_worker_used_buffers(transport_worker_t* worker);

    struct sockaddr* transport_worker_get_datagram_address(transport_worker_t* worker, transport_socket_family_t socket_family, int buffer_id);

    int transport_worker_peek(transport_worker_t* worker);

    void transport_worker_destroy(transport_worker_t* worker);

#if defined(__cplusplus)
}
#endif

#endif