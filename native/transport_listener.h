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
#include "transport_connector.h"
#include "transport_acceptor.h"

#if defined(__cplusplus)
extern "C"
{
#endif
  typedef struct transport_listener_configuration
  {
    size_t ring_size;
    int ring_flags;
    size_t workers_count;
  } transport_listener_configuration_t;

  typedef struct transport_listener
  {
    struct io_uring *ring;
    struct rlist listener_pool_link;
    intptr_t *workers;
    uint64_t *worker_ids;
    size_t workers_count;
    uint64_t worker_mask;
  } transport_listener_t;

  transport_listener_t *transport_listener_initialize(transport_listener_configuration_t *configuration);
  void transport_listener_destroy(transport_listener_t *listener);
  int transport_listener_get_worker_index(transport_listener_t *listener, int64_t worker_data);
  int transport_listener_prepare(struct transport_listener *listener, int worker_result, int64_t worker_data);
  int transport_listener_submit(struct transport_listener *listener);
#if defined(__cplusplus)
}
#endif

#endif
