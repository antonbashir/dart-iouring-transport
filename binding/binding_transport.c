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

struct io_uring *transport_activate(transport_t *transport)
{
  struct io_uring *ring = malloc(sizeof(struct io_uring));
  int32_t status = io_uring_queue_init(transport->ring_size, ring, 0);
  if (status)
  {
    log_error("io_urig init error: %d", status);
    free(ring);
    free(transport);
    return NULL;
  }
  transport->acceptor = transport_acceptor_share(transport->acceptor, ring);
  transport->channel = transport_channel_share(transport->channel, ring);
  transport_acceptor_accept(transport->acceptor);
  return ring;
}

void transport_cqe_seen(struct io_uring *ring, struct io_uring_cqe *cqe)
{
  io_uring_cqe_seen(ring, cqe);
}

struct io_uring_cqe *transport_consume(transport_t *transport, struct io_uring *ring)
{
  struct io_uring_cqe *cqe;
  if (likely(io_uring_wait_cqe(ring, &cqe) == 0))
  {
    if ((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_ACCEPT))
    {
      transport_acceptor_accept(transport->acceptor);
      if (unlikely(cqe->res < 0))
      {
        log_error("transport process cqe with result '%s' and user_data %d", strerror(-cqe->res), cqe->user_data);
        return cqe;
      }
      return cqe;
    }

    if (unlikely(cqe->res < 0))
    {
      log_error("transport process cqe with result '%s' and user_data %d", strerror(-cqe->res), cqe->user_data);
      return cqe;
    }

    if ((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_READ))
    {
      transport_channel_handle_read(transport->channel, cqe);
      return cqe;
    }

    if ((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_WRITE))
    {
      transport_channel_handle_write(transport->channel, cqe);
      return cqe;
    }

    return cqe;
  }

  return NULL;
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
  transport->channel = channel;
  transport->ring_size = configuration->ring_size;

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
