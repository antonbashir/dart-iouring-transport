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
#include "binding_balancer.h"

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
    bool ring_use_sq_poll;
  } transport_configuration_t;

  typedef struct transport
  {
    struct slab_arena arena;
    struct slab_cache cache;
    struct small_alloc allocator;
    struct quota quota;
    struct transport_balancer *channels;
    transport_channel_t *current_channel;
    transport_acceptor_t *acceptor;
    uint32_t ring_size;
    bool ring_use_sq_poll;
  } transport_t;

  transport_t *transport_initialize(transport_configuration_t *configuration,
                                    transport_channel_t *channel,
                                    transport_acceptor_t *acceptor);
  struct io_uring *transport_activate_accept(transport_t *transport);
  transport_channel_t *transport_activate_data(transport_t *transport);
  struct io_uring_cqe **transport_consume_data(transport_t *transport, struct io_uring_cqe **cqes, struct io_uring *ring);
  void transport_consume_accept(transport_t *transport, struct io_uring *ring);
  struct io_uring_cqe **transport_allocate_cqes(transport_t *transport);
  void transport_cqe_seen(struct io_uring *ring, int count);
  int transport_cqe_ready(struct io_uring *ring);
  void transport_close(transport_t *transport);
#if defined(__cplusplus)
}
#endif

#endif
