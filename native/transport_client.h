#ifndef TRANSPORT_CLIENT_H_INCLUDED
#define TRANSPORT_CLIENT_H_INCLUDED

#include <stdbool.h>
#include <netinet/in.h>
#include <sys/un.h>
#include <stdint.h>
#include <liburing.h>
#include <stdio.h>
#include "transport_constants.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_client_configuration
  {
    int32_t max_connections;
    uint32_t receive_buffer_size;
    uint32_t send_buffer_size;
    uint32_t default_pool;
  } transport_client_configuration_t;

  typedef struct transport_client
  {
    int fd;
    struct sockaddr_in inet_client_address;
    struct sockaddr_un unix_client_address;
    socklen_t client_address_length;
    transport_socket_mode_t mode;
  } transport_client_t;

  transport_client_t *transport_client_initialize_tcp(transport_client_configuration_t *configuration,
                                                      const char *ip,
                                                      int32_t port);

  transport_client_t *transport_client_initialize_udp(transport_client_configuration_t *configuration,
                                                      const char *ip,
                                                      int32_t port);

  transport_client_t *transport_client_initialize_unix_stream(transport_client_configuration_t *configuration,
                                                              const char *path,
                                                              uint8_t path_length);

  transport_client_t *transport_client_initialize_unix_dgram(transport_client_configuration_t *configuration,
                                                             const char *path,
                                                             uint8_t path_length);

  void transport_client_shutdown(transport_client_t *client);
#if defined(__cplusplus)
}
#endif

#endif
