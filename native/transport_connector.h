#ifndef TRANSPORT_CONNECTOR_H_INCLUDED
#define TRANSPORT_CONNECTOR_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include <stdio.h>

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_connector_configuration
  {
    int32_t max_connections;
    uint32_t receive_buffer_size;
    uint32_t send_buffer_size;
  } transport_connector_configuration_t;

  typedef struct transport_connector
  {
    int fd;
    struct sockaddr_in client_address;
    socklen_t client_address_length;
  } transport_connector_t;

  transport_connector_t *transport_connector_initialize(transport_connector_configuration_t *configuration,
                                                        const char *ip,
                                                        int32_t port);
                                                        
  void transport_connector_shutdown(transport_connector_t *connector);
#if defined(__cplusplus)
}
#endif

#endif
