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
#include "transport_server.h"
#include "transport_common.h"
#include "transport_constants.h"
#include "transport_socket.h"

transport_server_t *transport_server_initialize_tcp(transport_server_configuration_t *configuration,
                                                    const char *ip,
                                                    int32_t port)
{
  transport_server_t *server = malloc(sizeof(transport_server_t));
  if (!server)
  {
    return NULL;
  }
  server->family = INET;
  memset(&server->inet_server_address, 0, sizeof(server->inet_server_address));
  server->inet_server_address.sin_addr.s_addr = inet_addr(ip);
  server->inet_server_address.sin_port = htons(port);
  server->inet_server_address.sin_family = AF_INET;
  server->server_address_length = sizeof(server->inet_server_address);
  server->fd = transport_socket_create_server_tcp(configuration->max_connections, configuration->receive_buffer_size, configuration->send_buffer_size);
  if (server->fd < 0 || bind(server->fd, (struct sockaddr *)&server->inet_server_address, server->server_address_length) < 0)
  {
    free(server);
    return NULL;
  }

  if (listen(server->fd, configuration->max_connections) < 0)
  {
    free(server);
    return NULL;
  }
  return server;
}

transport_server_t *transport_server_initialize_udp(transport_server_configuration_t *configuration,
                                                    const char *ip,
                                                    int32_t port)
{
  transport_server_t *server = malloc(sizeof(transport_server_t));
  if (!server)
  {
    return NULL;
  }
  server->family = INET;
  memset(&server->inet_server_address, 0, sizeof(server->inet_server_address));
  server->inet_server_address.sin_addr.s_addr = inet_addr(ip);
  server->inet_server_address.sin_port = htons(port);
  server->inet_server_address.sin_family = AF_INET;
  server->server_address_length = sizeof(server->inet_server_address);
  server->fd = transport_socket_create_server_udp(configuration->receive_buffer_size, configuration->send_buffer_size);
  if (server->fd < 0 || bind(server->fd, (struct sockaddr *)&server->inet_server_address, server->server_address_length) < 0)
  {
    free(server);
    return NULL;
  }
  return server;
}

transport_server_t *transport_server_initialize_unix_stream(transport_server_configuration_t *configuration,
                                                            const char *path,
                                                            uint8_t path_length)
{
  transport_server_t *server = malloc(sizeof(transport_server_t));
  if (!server)
  {
    return NULL;
  }
  server->family = UNIX;
  memset(&server->unix_server_address, 0, sizeof(server->unix_server_address));
  server->unix_server_address.sun_family = AF_UNIX;
  strncpy(server->unix_server_address.sun_path, path, path_length);
  server->server_address_length = sizeof(server->unix_server_address);
  server->fd = transport_socket_create_server_unix_stream(configuration->receive_buffer_size, configuration->send_buffer_size);
  int32_t result = 0;
  if (server->fd < 0 || (result = bind(server->fd, (struct sockaddr *)&server->unix_server_address, server->server_address_length)) < 0)
  {
    free(server);
    return NULL;
  }
  if ((result = listen(server->fd, configuration->max_connections)) < 0)
  {
    free(server);
    return NULL;
  }
  return server;
}

transport_server_t *transport_server_initialize_unix_dgram(transport_server_configuration_t *configuration,
                                                           const char *path,
                                                           uint8_t path_length)
{
  transport_server_t *server = malloc(sizeof(transport_server_t));
  if (!server)
  {
    return NULL;
  }
  server->family = UNIX;
  memset(&server->unix_server_address, 0, sizeof(server->unix_server_address));
  server->unix_server_address.sun_family = AF_UNIX;
  strncpy(server->unix_server_address.sun_path, path, path_length);
  server->server_address_length = sizeof(server->unix_server_address);
  server->fd = transport_socket_create_server_unix_dgram(configuration->receive_buffer_size, configuration->send_buffer_size);
  if (server->fd < 0 || bind(server->fd, (struct sockaddr *)&server->unix_server_address, server->server_address_length) < 0)
  {
    free(server);
    return NULL;
  }
  return server;
}

void transport_server_shutdown(transport_server_t *server)
{
  shutdown(server->fd, SHUT_RDWR);
  free(server);
}