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
  int64_t socket_result = transport_socket_create_tcp(
      configuration->socket_configuration_flags,
      configuration->socket_receive_buffer_size,
      configuration->socket_send_buffer_size,
      configuration->socket_receive_low_at,
      configuration->socket_send_low_at,
      configuration->ip_ttl,
      configuration->tcp_keep_alive_idle,
      configuration->tcp_keep_alive_max_count,
      configuration->tcp_keep_alive_individual_count,
      configuration->tcp_max_segment_size,
      configuration->tcp_syn_count);
  if (socket_result < 0)
  {
    free(server);
    return NULL;
  }
  server->fd = socket_result;
  if (bind(server->fd, (struct sockaddr *)&server->inet_server_address, server->server_address_length) < 0)
  {
    free(server);
    return NULL;
  }
  if (listen(server->fd, configuration->socket_max_connections) < 0)
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
  int64_t socket_result = transport_socket_create_udp(
      configuration->socket_configuration_flags,
      configuration->socket_receive_buffer_size,
      configuration->socket_send_buffer_size,
      configuration->socket_receive_low_at,
      configuration->socket_send_low_at,
      configuration->ip_ttl,
      configuration->ip_multicast_interface,
      configuration->ip_multicast_ttl);
  if (socket_result < 0)
  {
    free(server);
    return NULL;
  }
  server->fd = socket_result;
  if (bind(server->fd, (struct sockaddr *)&server->inet_server_address, server->server_address_length) < 0)
  {
    free(server);
    return NULL;
  }
  return server;
}

transport_server_t *transport_server_initialize_unix_stream(transport_server_configuration_t *configuration,
                                                            const char *path)
{
  transport_server_t *server = malloc(sizeof(transport_server_t));
  if (!server)
  {
    return NULL;
  }
  server->family = UNIX;
  memset(&server->unix_server_address, 0, sizeof(server->unix_server_address));
  server->unix_server_address.sun_family = AF_UNIX;
  strcpy(server->unix_server_address.sun_path, path);
  server->server_address_length = sizeof(server->unix_server_address);
  int64_t result = transport_socket_create_unix_stream(
      configuration->socket_configuration_flags,
      configuration->socket_receive_buffer_size,
      configuration->socket_send_buffer_size,
      configuration->socket_receive_low_at,
      configuration->socket_send_low_at);
  if (result < 0)
  {
    free(server);
    return NULL;
  }
  server->fd = result;
  if ((result = bind(server->fd, (struct sockaddr *)&server->unix_server_address, server->server_address_length)) < 0)
  {
    free(server);
    return NULL;
  }
  if ((result = listen(server->fd, configuration->socket_max_connections)) < 0)
  {
    free(server);
    return NULL;
  }
  return server;
}

transport_server_t *transport_server_initialize_unix_dgram(transport_server_configuration_t *configuration,
                                                           const char *path)
{
  transport_server_t *server = malloc(sizeof(transport_server_t));
  if (!server)
  {
    return NULL;
  }
  server->family = UNIX;
  memset(&server->unix_server_address, 0, sizeof(server->unix_server_address));
  server->unix_server_address.sun_family = AF_UNIX;
  strcpy(server->unix_server_address.sun_path, path);
  server->server_address_length = sizeof(server->unix_server_address);
  int64_t result = transport_socket_create_unix_dgram(
      configuration->socket_configuration_flags,
      configuration->socket_receive_buffer_size,
      configuration->socket_send_buffer_size,
      configuration->socket_receive_low_at,
      configuration->socket_send_low_at);
  if (result < 0)
  {
    free(server);
    return NULL;
  }
  server->fd = result;
  if (bind(server->fd, (struct sockaddr *)&server->unix_server_address, server->server_address_length) < 0)
  {
    free(server);
    return NULL;
  }
  return server;
}

void transport_server_destroy(transport_server_t *server)
{
  free(server);
}