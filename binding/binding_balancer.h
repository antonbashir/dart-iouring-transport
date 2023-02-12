#ifndef BINDING_BALANCER_H_INCLUDED
#define BINDING_BALANCER_H_INCLUDED
#include "binding_channel.h"

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
    size_t count;
    transport_balancer_type type;
  } transport_balancer_configuration_t;

  struct transport_balancer
  {
    struct transport_channel *channels;
    size_t count;
    struct transport_channel *(*next)(void);
    void (*add)(struct transport_channel *);
  };

#if defined(__cplusplus)
}
#endif

#endif
