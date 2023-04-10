#include "dart/dart_api.h"
#include <stdio.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <liburing.h>
#include <string.h>
#include <errno.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdint.h>
#include <pthread.h>
#include <sys/time.h>
#include "transport.h"
#include "transport_common.h"
#include "transport_constants.h"
#include "transport_listener.h"
#include "transport_server.h"
#include "small/include/small/rlist.h"

transport_t *transport_initialize(transport_listener_configuration_t *listener_configuration,
                                  transport_worker_configuration_t *inbound_worker_configuration,
                                  transport_worker_configuration_t *outbound_worker_configuration)
{
  transport_t *transport = malloc(sizeof(transport_t));
  if (!transport)
  {
    return NULL;
  }

  transport->listener_configuration = listener_configuration;
  transport->inbound_worker_configuration = inbound_worker_configuration;
  transport->outbound_worker_configuration = outbound_worker_configuration;

  return transport;
}

void transport_destroy(transport_t *transport)
{
  free(transport->listener_configuration);
  free(transport->inbound_worker_configuration);
  free(transport->outbound_worker_configuration);
  free(transport);
}

void transport_cqe_advance(struct io_uring *ring, int count)
{
  io_uring_cq_advance(ring, count);
}

struct io_uring_cqe **transport_allocate_cqes(uint32_t cqe_count)
{
  return malloc(sizeof(struct io_uring_cqe) * cqe_count);
}

int transport_get_kernel_error()
{
  return errno;
}

int transport_close_descritor(int fd)
{
  shutdown(fd, SHUT_RDWR);
  return close(fd);
}