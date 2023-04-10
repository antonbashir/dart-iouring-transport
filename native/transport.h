#ifndef TRANSPORT_H_INCLUDED
#define TRANSPORT_H_INCLUDED

#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include "transport_listener.h"
#include "transport_server.h"
#include "transport_worker.h"
#include "transport_client.h"
#include "transport_listener_pool.h"
#include "dart/dart_api.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport
  {
    transport_listener_configuration_t *listener_configuration;
    transport_worker_configuration_t *inbound_worker_configuration;
    transport_worker_configuration_t *outbound_worker_configuration;
  } transport_t;

  transport_t *transport_initialize(transport_listener_configuration_t *listener_configuration,
                                    transport_worker_configuration_t *inbound_worker_configuration,
                                    transport_worker_configuration_t *outbound_worker_configuration);

  struct io_uring_cqe **transport_allocate_cqes(uint32_t cqe_count);

  void transport_cqe_advance(struct io_uring *ring, int count);

  void transport_destroy(transport_t *transport);

  int transport_close_descritor(int fd);

  int transport_get_kernel_error();
#if defined(__cplusplus)
}
#endif

#endif
