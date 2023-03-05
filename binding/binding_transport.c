#include "dart/dart_api.h"
#include <stdio.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <liburing.h>
#include <string.h>
#include <errno.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdint.h>
#include <pthread.h>
#include <sys/time.h>
#include "binding_transport.h"
#include "binding_common.h"
#include "binding_payload.h"
#include "binding_channel.h"
#include "binding_acceptor.h"

struct io_uring *transport_activate_accept(transport_t *transport)
{
  struct io_uring *ring = malloc(sizeof(struct io_uring));
  int32_t status = io_uring_queue_init(transport->ring_size, ring, IORING_SETUP_SQPOLL);
  if (status)
  {
    log_error("io_urig init error: %d", status);
    free(ring);
    free(transport);
    return NULL;
  }
  transport->acceptor = transport_acceptor_share(transport->acceptor, ring);
  transport_acceptor_accept(transport->acceptor);
  return ring;
}

transport_channel_t *transport_activate_data(transport_t *transport)
{
  struct io_uring *ring = malloc(sizeof(struct io_uring));
  int32_t status = io_uring_queue_init(transport->ring_size, ring, IORING_SETUP_SQPOLL);
  if (status)
  {
    log_error("io_urig init error: %d", status);
    free(ring);
    free(transport);
    return NULL;
  }
  transport_channel_t *channel = transport_channel_share(transport->current_channel, ring);
  transport->channels->add(transport->channels, channel);
  return channel;
}

void transport_cqe_seen(struct io_uring *ring, int count)
{
  io_uring_cq_advance(ring, count);
}

int transport_cqe_ready(struct io_uring *ring)
{
  return io_uring_cq_ready(ring);
}

struct io_uring_cqe **transport_allocate_cqes(transport_t *transport)
{
  return malloc(sizeof(struct io_uring_cqe) * transport->ring_size);
}

struct io_uring_cqe **transport_consume_data(transport_t *transport, struct io_uring_cqe **cqes, struct io_uring *ring)
{
  memset(cqes, 0, sizeof(struct io_uring_cqe) * transport->ring_size);
  if (!io_uring_peek_batch_cqe(ring, cqes, transport->ring_size))
  {
    struct io_uring_cqe *cqe;
    if (likely(io_uring_wait_cqe(ring, &cqe) == 0))
    {
      io_uring_peek_batch_cqe(ring, cqes, transport->ring_size);
      return cqes;
    }
    return NULL;
  }

  return cqes;
}

void transport_consume_accept(transport_t *transport, struct io_uring *ring)
{
  struct io_uring_cqe *cqe;
  if (likely(io_uring_wait_cqe(ring, &cqe) == 0))
  {
    log_debug("transport access process cqe with result %d and user_data %d", cqe->res, cqe->user_data);

    if (cqe->res < 0)
    {
      transport_acceptor_accept(transport->acceptor);
      io_uring_cqe_seen(ring, cqe);
      return;
    }

    if (cqe->res == 0)
    {
      io_uring_cqe_seen(ring, cqe);
      return;
    }

    transport_channel_t *channel = transport->channels->next(transport->channels);
    struct io_uring_sqe *sqe = provide_sqe(ring);
    io_uring_prep_msg_ring(sqe, channel->ring->ring_fd, cqe->res, TRANSPORT_PAYLOAD_MESSAGE, 0);
    io_uring_submit(ring);
    io_uring_cqe_seen(ring, cqe);
    transport_acceptor_accept(transport->acceptor);
  }
}

transport_t *transport_initialize(transport_configuration_t *configuration,
                                  transport_channel_t *channel,
                                  transport_acceptor_t *acceptor)
{
  log_set_level(configuration->log_level);
  log_set_colored(configuration->log_colored);

  transport_t *transport = malloc(sizeof(transport_t));
  if (!transport)
  {
    return NULL;
  }

  transport->acceptor = acceptor;
  transport->current_channel = channel;
  transport->ring_size = configuration->ring_size;
  transport->channels = transport_initialize_balancer();

  quota_init(&transport->quota, configuration->memory_quota);
  slab_arena_create(&transport->arena, &transport->quota, 0, configuration->slab_size, MAP_PRIVATE);
  slab_cache_create(&transport->cache, &transport->arena);
  float actual_allocation_factor;
  small_alloc_create(&transport->allocator,
                     &transport->cache,
                     configuration->slab_allocation_minimal_object_size,
                     configuration->slab_allocation_granularity,
                     configuration->slab_allocation_factor,
                     &actual_allocation_factor);

  log_info("transport initialized");
  return transport;
}

void transport_close(transport_t *transport)
{
  small_alloc_destroy(&transport->allocator);
  slab_cache_destroy(&transport->cache);
  slab_arena_destroy(&transport->arena);

  free(transport);
  log_info("transport closed");
}
