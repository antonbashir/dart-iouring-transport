#ifndef TRANSPORT_SERVER_H_INCLUDED
#define TRANSPORT_SERVER_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <sys/un.h>
#include <stdint.h>
#include "liburing.h"
#include <stdio.h>
#include "transport_constants.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_server_configuration
  {
    int32_t socket_max_connections;
    uint64_t socket_configuration_flags;
    uint32_t socket_receive_buffer_size;
    uint32_t socket_send_buffer_size;
    uint32_t socket_receive_low_at;
    uint32_t socket_send_low_at;
    uint16_t ip_ttl;
    uint32_t tcp_keep_alive_idle;
    uint32_t tcp_keep_alive_max_count;
    uint32_t tcp_keep_alive_individual_count;
    uint32_t tcp_max_segment_size;
    uint16_t tcp_syn_count;
    struct ip_mreqn *ip_multicast_interface;
    uint32_t ip_multicast_ttl;
  } transport_server_configuration_t;

  typedef struct transport_server
  {
    int fd;
    transport_socket_family_t family;
    struct sockaddr_in inet_server_address;
    struct sockaddr_un unix_server_address;
    socklen_t server_address_length;
  } transport_server_t;

  int transport_server_initialize_tcp(transport_server_t *server,
                                      transport_server_configuration_t *configuration,
                                      const char *ip,
                                      int32_t port);
  int transport_server_initialize_udp(transport_server_t *server, transport_server_configuration_t *configuration,
                                      const char *ip,
                                      int32_t port);
  int transport_server_initialize_unix_stream(transport_server_t *server,
                                              transport_server_configuration_t *configuration,
                                              const char *path);
  int transport_server_initialize_unix_dgram(transport_server_t *server,
                                             transport_server_configuration_t *configuration,
                                             const char *path);
  void transport_server_destroy(transport_server_t *server);

#if defined(__cplusplus)
}
#endif

#endif
