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
#include "transport_client.h"
#include "transport_common.h"
#include "transport_constants.h"
#include "transport_socket.h"

transport_client_t *transport_client_initialize(transport_client_configuration_t *configuration,
                                                      const char *ip,
                                                      int32_t port)
{
  transport_client_t *client = malloc(sizeof(transport_client_t));
  if (!client)
  {
    return NULL;
  }
  memset(&client->client_address, 0, sizeof(client->client_address));
  client->client_address.sin_addr.s_addr = inet_addr(ip);
  client->client_address.sin_port = htons(port);
  client->client_address.sin_family = AF_INET;
  client->client_address_length = sizeof(client->client_address);
  client->fd = transport_socket_create_client(configuration->max_connections, configuration->receive_buffer_size, configuration->send_buffer_size);
  if (client->fd < 0)
  {
    free(client);
    return NULL;
  }
  return client;
}

void transport_client_shutdown(transport_client_t *client)
{
  shutdown(client->fd, SHUT_RDWR);
  free(client);
}