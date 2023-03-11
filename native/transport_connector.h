#ifndef transport_CONNECTOR_H_INCLUDED
#define transport_CONNECTOR_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include "transport_transport.h"
#include <stdio.h>

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
    void *context;
    const char *client_ip;
    int32_t client_port;
    bool active;
  } transport_connector_t;

  transport_connector_t *transport_initialize_connector(transport_t *transport,
                                                        transport_connector_configuration_t *configuration,
                                                        const char *ip,
                                                        int32_t port);

  void transport_close_connector(transport_connector_t *connector);

  int32_t transport_connector_connect(transport_connector_t *connector);

  int transport_connector_loop(va_list input);
#if defined(__cplusplus)
}
#endif

#endif
