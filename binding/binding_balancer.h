#ifndef BINDING_BALANCER_H_INCLUDED
#define BINDING_BALANCER_H_INCLUDED
#include "binding_channel.h"
#include "binding_controller.h"
#include "small/include/small/rlist.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  struct transport_balancer
  {
    struct rlist channels;
    struct rlist *next_channel;
    uint16_t last_channel_index;
    size_t count;
    struct transport_channel *(*next)(struct transport_balancer *);
    void (*add)(struct transport_balancer *, struct transport_channel *);
    void (*remove)(struct transport_balancer *, struct transport_channel *);
  };

  struct transport_balancer *transport_initialize_balancer(transport_balancer_configuration_t *configuration, transport_t *transport);
#if defined(__cplusplus)
}
#endif

#endif