#ifndef TRANSPORT_LISTENER_H_INCLUDED
#define TRANSPORT_LISTENER_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include <stdio.h>
#include "small/include/small/ibuf.h"
#include "small/include/small/obuf.h"
#include "small/include/small/small.h"
#include "small/include/small/rlist.h"
#include "dart/dart_api_dl.h"
#include "transport_constants.h"

#if defined(__cplusplus)
extern "C"
{
#endif
  typedef struct transport_listener_configuration
  {
    size_t ring_size;
    int ring_flags;
    uint8_t workers_count;
    uint16_t buffers_count;
  } transport_listener_configuration_t;

  typedef struct transport_listener
  {
    struct io_uring *ring;
    struct rlist listener_pool_link;
    intptr_t *workers;
    struct iovec *buffers;
    uint8_t workers_count;
    uint16_t buffers_count;
  } transport_listener_t;

  transport_listener_t *transport_listener_initialize(transport_listener_configuration_t *configuration);
  int transport_listener_register_buffers(transport_listener_t *listener);
  void transport_listener_destroy(transport_listener_t *listener);
  int transport_listener_submit(struct transport_listener *listener);
  uint8_t transport_listener_get_worker_index(uint64_t worker_data);
  int transport_listener_prepare_result(transport_listener_t *listener, uint32_t result, uint64_t data);
  int transport_listener_prepare_data(transport_listener_t *listener, uint32_t result, uint64_t data);
  bool transport_listener_is_internal_result(struct io_uring_cqe* cqe);
  bool transport_listener_is_internal_data(struct io_uring_cqe* cqe);
#if defined(__cplusplus)
}
#endif

#endif
