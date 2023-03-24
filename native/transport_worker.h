#ifndef TRANSPORT_WORKER_H
#define TRANSPORT_WORKER_H

#include <stdint.h>
#include <stdio.h>
#include "transport_common.h"
#include "transport_listener_pool.h"
#include "transport_client.h"
#include "transport_acceptor.h"
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
    uint16_t buffer_shift;
    struct io_uring *ring;
    transport_listener_pool_t *listeners;
    struct iovec *buffers;
    uint32_t buffer_size;
    uint16_t buffers_count;
    int *used_buffers;
    uint64_t *used_buffers_offsets;
  } transport_worker_t;

  transport_worker_t *transport_worker_initialize(transport_worker_configuration_t *configuration, uint8_t id);

  int transport_worker_write(transport_worker_t *worker, int32_t fd, int16_t buffer_id, uint64_t offset, uint16_t event);
  int transport_worker_read(transport_worker_t *worker, int32_t fd, int16_t buffer_id, uint64_t offset, uint16_t event);
  int transport_worker_connect(transport_worker_t *worker, transport_client_t *client);
  int transport_worker_accept(transport_worker_t *worker, transport_acceptor_t *acceptor);
  int transport_worker_close(transport_worker_t *worker);
  int transport_worker_select_buffer(transport_worker_t *worker);
  int32_t transport_worker_get_fd(uint64_t worker_data);
  uint16_t transport_worker_get_buffer_index(transport_worker_t *worker, uint64_t worker_data);

  void transport_worker_destroy(transport_worker_t *worker);

#if defined(__cplusplus)
}
#endif

#endif