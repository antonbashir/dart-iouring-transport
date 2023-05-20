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
    uint16_t workers_count;
    int ring_flags;
  } transport_listener_configuration_t;

  typedef struct transport_listener
  {
    uint8_t id;
    struct io_uring *ring;
    size_t ring_size;
    struct rlist listener_pool_link;
    int *ready_workers;
    uint16_t workers_count;
  } transport_listener_t;

  int transport_listener_initialize(transport_listener_t * listener, transport_listener_configuration_t *configuration, uint8_t id);
  void transport_listener_close(transport_listener_t *listener);
  bool transport_listener_reap(transport_listener_t *listener, struct io_uring_cqe **cqes);
  void transport_listener_destroy(transport_listener_t *listener);
  void transport_listener_notify_idle(int64_t deadline);
  void transport_listener_notify_detach();
#if defined(__cplusplus)
}
#endif

#endif
