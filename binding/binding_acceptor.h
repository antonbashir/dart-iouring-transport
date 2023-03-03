#ifndef BINDING_ACCEPTOR_H_INCLUDED
#define BINDING_ACCEPTOR_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include "binding_transport.h"
#include <stdio.h>

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_acceptor_configuration
  {
    uint32_t ring_size;
    int32_t backlog;
  } transport_acceptor_configuration_t;

  typedef struct transport_acceptor
  {
    transport_t *transport;
    void *context;
    const char *server_ip;
    int32_t server_port;
    bool active;
  } transport_acceptor_t;

  transport_acceptor_t *transport_initialize_acceptor(transport_t *transport,
                                                      transport_acceptor_configuration_t *configuration,
                                                      const char *ip,
                                                      int32_t port);

  void transport_close_acceptor(transport_acceptor_t *acceptor);

  void transport_acceptor_register(transport_acceptor_t *acceptor, struct io_uring *ring);

  int transport_acceptor_accept(struct transport_acceptor *acceptor);
#if defined(__cplusplus)
}
#endif

#endif
