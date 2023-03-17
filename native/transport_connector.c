#include "dart/dart_api.h"
#include <stdio.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <liburing.h>
#include <string.h>
#include <errno.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/time.h>
#include "transport_connector.h"
#include "transport_common.h"
#include "transport_constants.h"
#include "transport_socket.h"

transport_connector_t *transport_connector_initialize(transport_connector_configuration_t *configuration,
                                                      const char *ip,
                                                      int32_t port)
{
  transport_connector_t *connector = malloc(sizeof(transport_connector_t));
  if (!connector)
  {
    return NULL;
  }
  memset(&connector->client_address, 0, sizeof(connector->client_address));
  connector->client_address.sin_addr.s_addr = inet_addr(ip);
  connector->client_address.sin_port = htons(port);
  connector->client_address.sin_family = AF_INET;
  connector->client_address_length = sizeof(connector->client_address);
  connector->fd = transport_socket_create_client(configuration->max_connections, configuration->receive_buffer_size, configuration->send_buffer_size);
  if (connector->fd < 0)
  {
    free(connector);
    return NULL;
  }
  transport_info("[connector]: initialized");
  return connector;
}

void transport_connector_shutdown(transport_connector_t *connector)
{
  shutdown(connector->fd, SHUT_RDWR);
  free(connector);
  transport_info("[connector]: shutdown");
}