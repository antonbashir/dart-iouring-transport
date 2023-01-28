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
  typedef enum transport_payload_type
  {
    TRANSPORT_PAYLOAD_READ,
    TRANSPORT_PAYLOAD_WRITE,
    TRANSPORT_PAYLOAD_ACCEPT,
    TRANSPORT_PAYLOAD_CONNECT,
    TRANSPORT_PAYLOAD_max4
  } transport_payload_type_t;

  typedef struct transport_data_payload
  {
    int32_t fd;
    transport_payload_type_t type;
    struct ibuf *buffer;
    char *position;
    int32_t size;
    int32_t buffer_size;
    size_t offset;
  } transport_data_payload_t;

  typedef struct transport_accept_payload
  {
    int32_t fd;
    transport_payload_type_t type;
    struct sockaddr_in client_addres;
    socklen_t client_addres_length;
  } transport_accept_payload_t;

  typedef struct transport_controller
  {
    transport_t *transport;
    size_t cqe_size;
    size_t internal_ring_size;
    size_t batch_message_limit;

    bool initialized;
    volatile bool active;

    void *message_ring;

    pthread_t thread_id;
    pthread_mutex_t initialization_mutex;
    pthread_cond_t initialization_condition;
    pthread_mutex_t shutdown_mutex;
    pthread_cond_t shutdown_condition;
  } transport_controller_t;

  typedef struct transport_controller_configuration
  {
    size_t cqe_size;
    size_t internal_ring_size;
    size_t batch_message_limit;
  } transport_controller_configuration_t;

  typedef struct transport_message
  {
    Dart_Port port;
    void *payload;
    transport_payload_type_t payload_type;
  } transport_message_t;

  transport_controller_t *transport_controller_start(transport_t *transport, transport_controller_configuration_t *configuration);
  void transport_controller_stop(transport_controller_t *controller);
  transport_message_t *transport_controller_create_message(transport_controller_t *controller, Dart_Port port, void *payload, transport_payload_type_t type);
  bool transport_controller_send(transport_controller_t *controller, transport_message_t *message);
#if defined(__cplusplus)
}
#endif

#endif