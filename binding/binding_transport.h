#ifndef BINDING_TRANSPORT_H_INCLUDED
#define BINDING_TRANSPORT_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include "small/include/small/small.h"
#include "small/include/small/slab_cache.h"
#include "small/include/small/slab_arena.h"
#include "small/include/small/quota.h"
#include "binding_channel.h"
#include "binding_acceptor.h"
#include "binding_channel_pool.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_configuration
  {
    int log_level;
    transport_channel_pool_mode_t channel_pool_mode;
  } transport_configuration_t;

  typedef struct transport
  {
    struct transport_channel_pool *channels;
    transport_acceptor_t* acceptor;
    transport_channel_configuration_t *channel_configuration;
    transport_acceptor_configuration_t *acceptor_configuration;
  } transport_t;

  transport_t *transport_initialize(transport_configuration_t *transport_configuration,
                                    transport_channel_configuration_t *channel_configuration,
                                    transport_acceptor_configuration_t *acceptor_configuration);

  transport_channel_t *transport_add_channel(transport_t *transport);

  int transport_consume(transport_t *transport, struct io_uring_cqe **cqes, struct io_uring *ring);

  void transport_accept(transport_t *transport, const char *ip, int port);

  struct io_uring_cqe **transport_allocate_cqes(transport_t *transport);

  void transport_cqe_advance(struct io_uring *ring, int count);

  void transport_shutdown(transport_t *transport);
  
  void transport_destroy(transport_t *transport);

  int transport_close_descritor(transport_t *transport, int fd);
#if defined(__cplusplus)
}
#endif

#endif
