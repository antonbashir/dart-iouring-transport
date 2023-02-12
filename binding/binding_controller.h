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
  typedef struct transport_controller
  {
    transport_t *transport;
    size_t cqe_size;
    size_t internal_ring_size;
    size_t batch_message_limit;
    int ring_retry_max_count;

    volatile bool initialized;
    volatile bool suspended;
    volatile bool active;
    volatile bool connected;

    void *context;

    pthread_t thread_id;
    pthread_mutex_t suspended_mutex;
    pthread_cond_t suspended_condition;
    pthread_mutex_t shutdown_mutex;
    pthread_cond_t shutdown_condition;
  } transport_controller_t;

  typedef struct transport_controller_configuration
  {
    size_t cqe_size;
    size_t internal_ring_size;
    size_t batch_message_limit;
    int ring_retry_max_count;
  } transport_controller_configuration_t;

  transport_controller_t *transport_controller_start(transport_t *transport, transport_controller_configuration_t *configuration);
  void transport_controller_stop(transport_controller_t *controller);
  bool transport_controller_send(transport_controller_t *controller, void *message);
#if defined(__cplusplus)
}
#endif

#endif