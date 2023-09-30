#ifndef TRANSPORT_BUFFERS_POOL_INCLUDED
#define TRANSPORT_BUFFERS_POOL_INCLUDED

#include "trivia/common.h"
#include "transport_constants.h"

struct transport_buffers_pool
{
  int32_t *ids;
  size_t count;
  size_t size;
};

static inline int transport_buffers_pool_create(struct transport_buffers_pool *pool, size_t size)
{
  pool->size = size;
  pool->count = 0;
  pool->ids = (int32_t *)malloc(size * sizeof(int32_t));
  memset(pool->ids, 0, size * sizeof(int32_t));
  return (pool->ids == NULL ? -1 : 0);
}

static inline void transport_buffers_pool_destroy(struct transport_buffers_pool *pool)
{
  free(pool->ids);
  pool->ids = NULL;
}

static inline void transport_buffers_pool_push(struct transport_buffers_pool *pool, int32_t id)
{
  pool->ids[pool->count++] = id;
}

static inline int32_t transport_buffers_pool_pop(struct transport_buffers_pool *pool)
{
  if (unlikely(pool->count == 0))
    return TRANSPORT_BUFFER_USED;
  return pool->ids[--pool->count];
}

#endif
