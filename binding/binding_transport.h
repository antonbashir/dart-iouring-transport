#ifndef BINDING_TRANSPORT_H_INCLUDED
#define BINDING_TRANSPORT_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include "small/include/small/small.h"
#include "small/include/small/slab_cache.h"
#include "small/include/small/slab_arena.h"
#include "small/include/small/quota.h"
#include "binding_channel.h"
#include "binding_acceptor.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_configuration
  {
    uint32_t slab_size;
    size_t memory_quota;
    uint32_t slab_allocation_minimal_object_size;
    size_t slab_allocation_granularity;
    float slab_allocation_factor;
    int log_level;
    bool log_colored;
    size_t ring_size;
  } transport_configuration_t;

  typedef struct transport
  {
    struct slab_arena arena;
    struct slab_cache cache;
    struct small_alloc allocator;
    struct quota quota;
    struct io_uring *ring;
    transport_channel_t *channel;
    transport_acceptor_t *acceptor;
    uint32_t ring_size;
  } transport_t;

  typedef enum
  {
    TRANSPORT_BALANCER_ROUND_ROBBIN,
    TRANSPORT_BALANCER_LEAST_CONNECTIONS,
    TRANSPORT_BALANCER_max
  } transport_balancer_type;

  transport_t *transport_initialize(transport_configuration_t *configuration,
                                    transport_channel_t *channel,
                                    transport_acceptor_t *acceptor);
  int transport_activate(transport_t *transport);
  struct io_uring_cqe *transport_consume(transport_t *transport);
  void transport_cqe_seen(transport_t *transport, struct io_uring_cqe *cqe);
  void transport_close(transport_t *transport);
#if defined(__cplusplus)
}
#endif

#endif
