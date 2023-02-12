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
  } transport_configuration_t;

  typedef struct transport
  {
    struct slab_arena arena;
    struct slab_cache cache;
    struct small_alloc allocator;
    struct quota quota;
  } transport_t;

  transport_t *transport_initialize(transport_configuration_t *configuration);
  void transport_close(transport_t *transport);
#if defined(__cplusplus)
}
#endif

#endif
