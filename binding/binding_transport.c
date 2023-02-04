#include "binding_transport.h"
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
#include "binding_log.h"

transport_t *transport_initialize(transport_configuration_t *configuration)
{
  transport_t *transport = malloc(sizeof(transport_t));
  if (!transport)
  {
    return NULL;
  }

  if (io_uring_queue_init(configuration->ring_size, &transport->ring, 0) != 0)
  {
    free(&transport->ring);
    return NULL;
  }

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
  io_uring_queue_exit(&transport->ring);

  small_alloc_destroy(&transport->allocator);
  slab_cache_destroy(&transport->cache);
  slab_arena_destroy(&transport->arena);

  log_info("transport closed");
  free(transport);
}
