#ifndef BINDING_CONNECTION_H_INCLUDED
#define BINDING_CONNECTION_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include "binding_transport.h"
#include "binding_listener.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_connection_configuration
  {
    bool verbose;
  } transport_connection_configuration_t;

  typedef struct transport_connection
  {
    transport_t *transport;
    transport_listener_t *listener;
    struct mempool accept_payload_pool;
    Dart_Port accept_port;
    Dart_Port connect_port;
  } transport_connection_t;

  transport_connection_t *transport_initialize_connection(transport_t *transport,
                                                          transport_listener_t *listener,
                                                          transport_connection_configuration_t *configuration,
                                                          Dart_Port accept_port,
                                                          Dart_Port connect_port);
  void transport_close_connection(transport_connection_t *connection);

  int32_t transport_connection_queue_accept(transport_connection_t *connection, int32_t server_socket_fd);
  int32_t transport_connection_queue_connect(transport_connection_t *connection, int32_t socket_fd, const char *ip, int32_t port);

  transport_accept_payload_t *transport_connection_allocate_accept_payload(transport_connection_t *connection);
  void transport_connection_free_accept_payload(transport_connection_t *connection, transport_accept_payload_t *payload);
#if defined(__cplusplus)
}
#endif

#endif
