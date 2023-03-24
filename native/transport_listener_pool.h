#ifndef transport_listener_POOL_H_INCLUDED
#define transport_listener_POOL_H_INCLUDED
#include "transport_listener.h"
#include "small/include/small/rlist.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_listener_pool
  {
    struct rlist listeners;
    struct rlist *next_listener;
    uint16_t next_listener_index;
    size_t count;
  } transport_listener_pool_t;

  transport_listener_pool_t *transport_listener_pool_initialize();
  void transport_listener_pool_add(transport_listener_pool_t *pool, transport_listener_t *listener);
  void transport_listener_pool_remove(transport_listener_pool_t *pool, transport_listener_t *listener);

#if defined(__cplusplus)
}
#endif

#endif