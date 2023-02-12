#ifndef BINDING_BALANCER_H_INCLUDED
#define BINDING_BALANCER_H_INCLUDED
#include "binding_channel.h"
#include "small/include/small/rlist.h"

#if defined(__cplusplus)
extern "C"
{
#endif
  typedef enum
  {
    TRANSPORT_BALANCER_ROUND_ROBBIN,
    TRANSPORT_BALANCER_LEAST_CONNECTIONS,
    TRANSPORT_BALANCER_max
  } transport_balancer_type;

  typedef struct transport_balancer_configuration
  {
    transport_balancer_type type;
  } transport_balancer_configuration_t;

  struct transport_balancer
  {
    struct rlist *channels;
    struct rlist *next;
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
