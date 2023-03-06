#ifndef BINDING_ACCEPTOR_H_INCLUDED
#define BINDING_ACCEPTOR_H_INCLUDED
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
    int32_t backlog;
    uint32_t ring_size;
    int ring_flags;
  } transport_acceptor_configuration_t;

  typedef struct transport_acceptor
  {
    struct io_uring *ring;
    int fd;
    struct sockaddr_in server_address;
    socklen_t server_address_length;
    const char *ip;
    int32_t port;
    int32_t backlog;
  } transport_acceptor_t;

  transport_acceptor_t *transport_acceptor_initialize(transport_acceptor_configuration_t *configuration,
                                                      const char *ip,
                                                      int32_t port);

  void transport_acceptor_close(transport_acceptor_t *acceptor);
#if defined(__cplusplus)
}
#endif

#endif
