#include "transport_listener_pool.h"
#include "transport_common.h"

transport_listener_t *transport_listener_pool_next(transport_listener_pool_t *pool)
{
  if (unlikely(!pool->next_listener))
  {
    pool->next_listener = pool->listener.next;
    pool->next_listener_index = 0;
    return rlist_entry(pool->next_listener, transport_listener_t, listener_pool_link);
  }
  if (pool->next_listener_index + 1 == pool->count)
  {
    pool->next_listener = pool->listener.next;
    pool->next_listener_index = 0;
    return rlist_entry(pool->next_listener, transport_listener_t, listener_pool_link);
  }
  pool->next_listener = pool->next_listener->next;
  pool->next_listener_index++;
  return rlist_entry(pool->next_listener, transport_listener_t, listener_pool_link);
}

void transport_listener_pool_add(transport_listener_pool_t *pool, transport_listener_t *listener)
{
  rlist_add_entry(&pool->listener, listener, listener_pool_link);
  pool->count++;
}

void transport_listener_pool_remove(transport_listener_pool_t *pool, transport_listener_t *listener)
{
  rlist_del_entry(listener, listener_pool_link);
  pool->count--;
}

transport_listener_pool_t *transport_listener_pool_initialize()
{
  transport_listener_pool_t *listener_pool = malloc(sizeof(transport_listener_pool_t));
  if (!listener_pool)
  {
    return NULL;
  }
  listener_pool->next_listener = NULL;
  listener_pool->count = 0;
  listener_pool->next_listener_index = 0;
  rlist_create(&listener_pool->listener);

  return listener_pool;
}
