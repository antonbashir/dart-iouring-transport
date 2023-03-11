#ifndef transport_CHANNEL_POOL_H_INCLUDED
#define transport_CHANNEL_POOL_H_INCLUDED
#include "transport_channel.h"
#include "small/include/small/rlist.h"

#if defined(__cplusplus)
extern "C"
{
#endif


  struct transport_channel_pool
  {
    struct rlist channels;
    struct rlist *next_channel;
    uint16_t last_channel_index;
    size_t count;
  };

  struct transport_channel_pool *transport_channel_pool_initialize();
  struct transport_channel *transport_channel_pool_next(struct transport_channel_pool *);
  void transport_channel_pool_add(struct transport_channel_pool *, struct transport_channel *);
  void transport_channel_pool_remove(struct transport_channel_pool *, struct transport_channel *);

#if defined(__cplusplus)
}
#endif

#endif