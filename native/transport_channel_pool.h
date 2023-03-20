#ifndef TRANSPORT_CHANNEL_POOL_H_INCLUDED
#define TRANSPORT_CHANNEL_POOL_H_INCLUDED
#include "transport_channel.h"
#include "small/include/small/rlist.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_channel_pool
  {
    struct rlist channels;
    struct rlist *next_channel;
    uint16_t next_channel_index;
    size_t count;
  } transport_channel_pool_t;

  transport_channel_pool_t *transport_channel_pool_initialize();
  struct transport_channel *transport_channel_pool_next(transport_channel_pool_t *pool);
  void transport_channel_pool_add(transport_channel_pool_t *pool, transport_channel_t *channel);
  void transport_channel_pool_remove(transport_channel_pool_t *pool, transport_channel_t *channel);

#if defined(__cplusplus)
}
#endif

#endif