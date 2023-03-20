#ifndef TRANSPORT_WORKER_H
#define TRANSPORT_WORKER_H

#include <stdint.h>
#include <stdio.h>
#include "transport_channel_pool.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_worker_configuration
  {
    uint32_t buffers_count;
    uint32_t buffer_size;
    size_t ring_size;
    int ring_flags;
  } transport_worker_configuration_t;

  typedef struct transport_worker
  {
    int64_t id;
    struct io_uring *ring;
    transport_channel_pool_t *channels;
    struct iovec *buffers;
    uint32_t buffer_size;
    uint32_t buffers_count;
    int *used_buffers;
    int *used_buffers_offsets;
    int available_buffer_id;
  } transport_worker_t;

  transport_worker_t *transport_worker_initialize(transport_worker_configuration_t *configuration, int64_t id);

  int transport_worker_write(transport_worker_t *worker, int fd, int buffer_id, int64_t offset, int64_t event);
  int transport_worker_read(transport_worker_t *worker, int fd, int buffer_id, int64_t offset, int64_t event);
  int transport_worker_connect(transport_worker_t *worker, transport_connector_t *connector);
  int transport_worker_accept(transport_worker_t *worker, transport_acceptor_t *acceptor);
  int transport_worker_close(transport_worker_t *worker);
  int transport_worker_select_buffer(transport_worker_t *worker);

  void transport_worker_destroy(transport_worker_t *worker);

#if defined(__cplusplus)
}
#endif

#endif