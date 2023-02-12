#ifndef BINDING_CONNECTOR_H_INCLUDED
#define BINDING_CONNECTOR_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include "binding_transport.h"
#include "binding_controller.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_connector_configuration
  {
    uint32_t ring_size;
  } transport_connector_configuration_t;

  typedef struct transport_connector
  {
    transport_t *transport;
    transport_controller_t *controller;
    void *context;
    const char *client_ip;
    int32_t client_port;
    Dart_Port dart_port;
    bool active;
  } transport_connector_t;

  transport_connector_t *transport_initialize_connector(transport_t *transport,
                                                        transport_controller_t *controller,
                                                        transport_connector_configuration_t *configuration,
                                                        const char *ip,
                                                        int32_t port,
                                                        Dart_Port dart_port);

  void transport_close_connector(transport_connector_t *connector);

  int32_t transport_connector_connect(transport_connector_t *connector);
#if defined(__cplusplus)
}
#endif

#endif
