#ifndef TRANSPORT_SERVER_H_INCLUDED
#define TRANSPORT_SERVER_H_INCLUDED
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

  typedef struct transport_server_configuration
  {
    int32_t max_connections;
    uint32_t receive_buffer_size;
    uint32_t send_buffer_size;
    uint64_t read_timeout;
    uint64_t write_timeout;
  } transport_server_configuration_t;

  typedef struct transport_server
  {
    int fd;
    transport_socket_family_t family;
    struct sockaddr_in inet_server_address;
    struct sockaddr_un unix_server_address;
    socklen_t server_address_length;
    uint64_t read_timeout;
    uint64_t write_timeout;
  } transport_server_t;

  transport_server_t *transport_server_initialize_tcp(transport_server_configuration_t *configuration,
                                                      const char *ip,
                                                      int32_t port);
  transport_server_t *transport_server_initialize_udp(transport_server_configuration_t *configuration,
                                                      const char *ip,
                                                      int32_t port);
  transport_server_t *transport_server_initialize_unix_stream(transport_server_configuration_t *configuration,
                                                              const char *path);
  transport_server_t *transport_server_initialize_unix_dgram(transport_server_configuration_t *configuration,
                                                             const char *path);
  void transport_server_destroy(transport_server_t *server);
#if defined(__cplusplus)
}
#endif

#endif
