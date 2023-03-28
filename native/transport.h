#ifndef TRANSPORT_H_INCLUDED
#define TRANSPORT_H_INCLUDED

#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include "transport_listener.h"
#include "transport_acceptor.h"
#include "transport_worker.h"
#include "transport_client.h"
#include "transport_listener_pool.h"
#include "dart/dart_api.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_configuration
  {
    uint8_t log_level;
  } transport_configuration_t;

  typedef struct transport
  {
    transport_configuration_t *transport_configuration;
    transport_listener_configuration_t *listener_configuration;
    transport_client_configuration_t *client_configuration;
    transport_acceptor_configuration_t *acceptor_configuration;
    transport_worker_configuration_t *worker_configuration;
  } transport_t;

  transport_t *transport_initialize(transport_configuration_t *transport_configuration,
                                    transport_listener_configuration_t *listener_configuration,
                                    transport_worker_configuration_t *worker_configuration,
                                    transport_client_configuration_t *client_configuration,
                                    transport_acceptor_configuration_t *acceptor_configuration);

  int transport_consume(uint32_t cqe_count, struct io_uring_cqe **cqes, struct io_uring *ring, int64_t timeout_seconds, int64_t timeout_nanos);

  int transport_peek(uint32_t cqe_count, struct io_uring_cqe **cqes, struct io_uring *ring);

  struct io_uring_cqe **transport_allocate_cqes(uint32_t cqe_count);

  void transport_cqe_advance(struct io_uring *ring, int count);

  void transport_destroy(transport_t *transport);

  int transport_close_descritor(int fd);
#if defined(__cplusplus)
}
#endif

#endif
