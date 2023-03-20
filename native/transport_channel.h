#ifndef TRANSPORT_CHANNEL_H_INCLUDED
#define TRANSPORT_CHANNEL_H_INCLUDED
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
  typedef struct transport_channel_configuration
  {
    size_t ring_size;
    int ring_flags;
    size_t workers_count;
  } transport_channel_configuration_t;

  typedef struct transport_channel
  {
    struct io_uring *ring;
    struct rlist channel_pool_link;
    intptr_t *workers;
    uint64_t *worker_ids;
    size_t workers_count;
    size_t worker_mask;
  } transport_channel_t;

  transport_channel_t *transport_channel_initialize(transport_channel_configuration_t *configuration);
  void transport_channel_destroy(transport_channel_t *channel);
  int transport_channel_submit(struct transport_channel *channel, int worker_result, int64_t worker_data);
#if defined(__cplusplus)
}
#endif

#endif
