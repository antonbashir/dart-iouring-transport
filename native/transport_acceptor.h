#ifndef TRANSPORT_ACCEPTOR_H_INCLUDED
#define TRANSPORT_ACCEPTOR_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include <stdio.h>

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_acceptor_configuration
  {
    int32_t max_connections;
    uint32_t receive_buffer_size;
    uint32_t send_buffer_size;
  } transport_acceptor_configuration_t;

  typedef struct transport_acceptor
  {
    int fd;
    struct sockaddr_in server_address;
    socklen_t server_address_length;
  } transport_acceptor_t;

  transport_acceptor_t *transport_acceptor_initialize(transport_acceptor_configuration_t *configuration,
                                                      const char *ip,
                                                      int32_t port);
  void transport_acceptor_shutdown(transport_acceptor_t *acceptor);
#if defined(__cplusplus)
}
#endif

#endif
