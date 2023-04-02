#ifndef TRANSPORT_WORKER_H
#define TRANSPORT_WORKER_H

#include <stdint.h>
#include <stdio.h>
#include "transport_common.h"
#include "transport_listener_pool.h"
#include "transport_client.h"
#include "transport_server.h"
#include "transport_collections.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_worker_configuration
  {
    uint16_t buffers_count;
    uint32_t buffer_size;
    size_t ring_size;
    int ring_flags;
  } transport_worker_configuration_t;

  typedef struct transport_worker
  {
    uint8_t id;
    struct io_uring *ring;
    transport_listener_pool_t *listeners;
    struct iovec *buffers;
    uint32_t buffer_size;
    uint16_t buffers_count;
    int64_t *used_buffers;
    struct msghdr *inet_used_messages;
    struct msghdr *unix_used_messages;
  } transport_worker_t;

  transport_worker_t *transport_worker_initialize(transport_worker_configuration_t *configuration, uint8_t id);

  int transport_worker_write(transport_worker_t *worker, uint32_t fd, uint16_t buffer_id, uint32_t offset, uint16_t event);
  int transport_worker_read(transport_worker_t *worker, uint32_t fd, uint16_t buffer_id, uint32_t offset, uint16_t event);
  int transport_worker_connect(transport_worker_t *worker, transport_client_t *client);
  int transport_worker_accept(transport_worker_t *worker, transport_server_t *server);
  int transport_worker_send_message(transport_worker_t *worker, uint32_t fd, uint16_t buffer_id, struct sockaddr *address, transport_socket_family_t socket_family, int message_flags, uint16_t event);
  int transport_worker_respond_message(transport_worker_t *worker, uint32_t fd, uint16_t buffer_id, transport_socket_family_t socket_family, int message_flags, uint16_t event);
  int transport_worker_receive_message(transport_worker_t *worker, uint32_t fd, uint16_t buffer_id, transport_socket_family_t socket_family, int message_flags, uint16_t event);
  int transport_worker_select_buffer(transport_worker_t *worker);
  void transport_worker_reuse_buffer(transport_worker_t *worker, uint16_t buffer_id);
  void transport_worker_free_buffer(transport_worker_t *worker, uint16_t buffer_id);

  int transport_worker_peek(uint32_t cqe_count, struct io_uring_cqe **cqes, struct io_uring *ring);

  void transport_worker_destroy(transport_worker_t *worker);

#if defined(__cplusplus)
}
#endif

#endif