#ifndef BINDING_CONTROLLER_H_INCLUDED
#define BINDING_CONTROLLER_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include <pthread.h>
#include "dart/dart_api_dl.h"
#include "binding_transport.h"

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

  typedef struct transport_controller
  {
    transport_t *transport;
    void *balancer;
    size_t internal_ring_size;
    int ring_retry_max_count;

    volatile bool initialized;
    volatile bool active;

    void *context;

    pthread_t thread_id;
    pthread_mutex_t shutdown_mutex;
    pthread_cond_t shutdown_condition;
  } transport_controller_t;

  typedef struct transport_controller_configuration
  {
    int ring_retry_max_count;
    size_t internal_ring_size;
    transport_balancer_configuration_t *balancer_configuration;
  } transport_controller_configuration_t;

  transport_controller_t *transport_controller_start(transport_t *transport, transport_controller_configuration_t *configuration);
  void transport_controller_stop(transport_controller_t *controller);
  bool transport_controller_send(transport_controller_t *controller, void *message);
#if defined(__cplusplus)
}
#endif

#endif