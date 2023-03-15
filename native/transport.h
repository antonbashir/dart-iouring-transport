#ifndef TRANSPORT_H_INCLUDED
#define TRANSPORT_H_INCLUDED

#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include "transport_channel.h"
#include "transport_acceptor.h"
#include "transport_channel_pool.h"
#include "dart/dart_api.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_configuration
  {
    Dart_Port logging_port;
  } transport_configuration_t;

  typedef struct transport
  {
    struct transport_channel_pool *channels;
    transport_acceptor_t *acceptor;
    transport_channel_configuration_t *channel_configuration;
    transport_acceptor_configuration_t *acceptor_configuration;
  } transport_t;

  transport_t *transport_initialize(transport_configuration_t *transport_configuration,
                                    transport_channel_configuration_t *channel_configuration,
                                    transport_acceptor_configuration_t *acceptor_configuration);

  transport_channel_t *transport_add_channel(transport_t *transport);

  int transport_consume(uint32_t cqe_count, struct io_uring_cqe **cqes, struct io_uring *ring, int64_t timeout_seconds, int64_t timeout_nanos);
  
  int transport_wait(uint32_t cqe_count, struct io_uring_cqe **cqes, struct io_uring *ring);

  int transport_peek(uint32_t cqe_count, struct io_uring_cqe **cqes, struct io_uring *ring);

  void transport_accept(transport_t *transport, const char *ip, int port);

  struct io_uring_cqe **transport_allocate_cqes(uint32_t cqe_count);

  void transport_cqe_advance(struct io_uring *ring, int count);

  void transport_shutdown(transport_t *transport);

  void transport_destroy(transport_t *transport);

  int transport_close_descritor(int fd);

  void transport_handle_dart_messages();
#if defined(__cplusplus)
}
#endif

#endif
