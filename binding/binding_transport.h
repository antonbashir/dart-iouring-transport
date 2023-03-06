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
    int log_level;
    bool log_colored;
    size_t channel_ring_size;
    size_t acceptor_ring_size;
    int channel_ring_flags;
    int acceptor_ring_flags;
  } transport_configuration_t;

  typedef struct transport
  {
    struct transport_balancer *channels;
    transport_channel_t *current_channel;
    transport_acceptor_t *acceptor;
    uint32_t channel_ring_size;
    uint32_t acceptor_ring_size;
    int channel_ring_flags;
    int acceptor_ring_flags;
  } transport_t;

  transport_t *transport_initialize(transport_configuration_t *configuration,
                                    transport_channel_t *channel,
                                    transport_acceptor_t *acceptor);

  transport_acceptor_t *transport_activate_acceptor(transport_t *transport);

  transport_channel_t *transport_activate_channel(transport_t *transport);

  int transport_consume(transport_t *transport, struct io_uring_cqe **cqes, struct io_uring *ring);

  void transport_accept(transport_t *transport, struct io_uring *ring);

  struct io_uring_cqe **transport_allocate_cqes(transport_t *transport);

  void transport_cqe_advance(struct io_uring *ring, int count);

  int transport_cqe_ready(struct io_uring *ring);

  void transport_close(transport_t *transport);
#if defined(__cplusplus)
}
#endif

#endif
