#ifndef BINDING_CHANNEL_POOL_H_INCLUDED
#define BINDING_CHANNEL_POOL_H_INCLUDED
#include "binding_channel.h"
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
    struct transport_channel *(*next)(struct transport_channel_pool *);
    void (*add)(struct transport_channel_pool *, struct transport_channel *);
    void (*remove)(struct transport_channel_pool *, struct transport_channel *);
  };

  struct transport_channel_pool *transport_channel_pool_initialize();
#if defined(__cplusplus)
}
#endif

#endif