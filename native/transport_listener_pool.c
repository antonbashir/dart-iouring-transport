#include "transport_listener_pool.h"
#include "transport_common.h"

void transport_listener_pool_add(transport_listener_pool_t *pool, transport_listener_t *listener)
{
  rlist_add_entry(pool->listeners, listener, listener_pool_link);
}

transport_listener_pool_t *transport_listener_pool_initialize(transport_listener_t* first)
{
  transport_listener_pool_t *listener_pool = malloc(sizeof(transport_listener_pool_t));
  if (!listener_pool)
  {
    return NULL;
  }
  listener_pool->listeners = &first->listener_pool_link;
  rlist_create(listener_pool->listeners);
  listener_pool->next_listener = listener_pool->listeners;

  return listener_pool;
}
