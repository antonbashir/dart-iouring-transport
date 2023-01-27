#ifndef BINDING_LISTENER_H_INCLUDED
#define BINDING_LISTENER_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include "small/include/small/mempool.h"
#include "small/include/small/small.h"
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
    TRANSPORT_PAYLOAD_max
  } transport_payload_type_t;

  typedef struct transport_data_payload
  {
    int32_t fd;
    transport_payload_type_t type;
    struct ibuf *buffer;
    int32_t size;
  } transport_data_payload_t;

  typedef struct transport_accept_payload
  {
    int32_t fd;
    transport_payload_type_t type;
    struct sockaddr_in client_addres;
    socklen_t client_addres_length;
  } transport_accept_payload_t;

  typedef struct transport_listener
  {
    transport_t *transport;
    size_t cqe_size;

    struct mempool cqe_pool;
    struct mempool message_pool;

    bool initialized;
    volatile bool active;

    pthread_t thread_id;
    pthread_mutex_t initialization_mutex;
    pthread_cond_t initialization_condition;
    pthread_mutex_t shutdown_mutex;
    pthread_cond_t shutdown_condition;
  } transport_listener_t;

  typedef struct transport_listener_configuration
  {
    size_t cqe_size;
  } transport_listener_configuration_t;

  typedef struct transport_message
  {
    Dart_Port port;
    void *payload;
    transport_payload_type_t payload_type;
  } transport_message_t;

  transport_listener_t *transport_listener_start(transport_t *transport, transport_listener_configuration_t *configuration);
  void transport_listener_stop(transport_listener_t *listener);
  transport_message_t *transport_listener_create_message(transport_listener_t *listener, Dart_Port port, void *payload);
#if defined(__cplusplus)
}
#endif

#endif