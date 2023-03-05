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
  } transport_acceptor_configuration_t;

  typedef struct transport_acceptor
  {
    void *context;
    struct io_uring *ring;
  } transport_acceptor_t;

  transport_acceptor_t *transport_initialize_acceptor(transport_acceptor_configuration_t *configuration,
                                                      const char *ip,
                                                      int32_t port);

  void transport_close_acceptor(transport_acceptor_t *acceptor);

  transport_acceptor_t *transport_acceptor_share(transport_acceptor_t *source, struct io_uring *ring);

  int transport_acceptor_accept(struct transport_acceptor *acceptor);
#if defined(__cplusplus)
}
#endif

#endif
