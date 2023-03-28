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
#include "transport_acceptor.h"
#include "small/include/small/rlist.h"

transport_t *transport_initialize(transport_configuration_t *transport_configuration,
                                  transport_listener_configuration_t *listener_configuration,
                                  transport_worker_configuration_t *worker_configuration,
                                  transport_client_configuration_t *client_configuration,
                                  transport_acceptor_configuration_t *acceptor_configuration)
{
  transport_t *transport = malloc(sizeof(transport_t));
  if (!transport)
  {
    return NULL;
  }

  transport->transport_configuration = transport_configuration;
  transport->acceptor_configuration = acceptor_configuration;
  transport->listener_configuration = listener_configuration;
  transport->client_configuration = client_configuration;
  transport->worker_configuration = worker_configuration;

  return transport;
}

void transport_destroy(transport_t *transport)
{
  free(transport->transport_configuration);
  free(transport->acceptor_configuration);
  free(transport->listener_configuration);
  free(transport->client_configuration);
  free(transport->worker_configuration);
}

void transport_cqe_advance(struct io_uring *ring, int count)
{
  io_uring_cq_advance(ring, count);
}

struct io_uring_cqe **transport_allocate_cqes(uint32_t cqe_count)
{
  return malloc(sizeof(struct io_uring_cqe) * cqe_count);
}

int transport_consume(uint32_t cqe_count, struct io_uring_cqe **cqes, struct io_uring *ring, int64_t timeout_seconds, int64_t timeout_nanos)
{
  int count = 0;
  if (!(count = io_uring_peek_batch_cqe(ring, &cqes[0], cqe_count)))
  {
    struct __kernel_timespec timeout = {
        .tv_sec = timeout_seconds,
        .tv_nsec = timeout_nanos,
    };
    if (likely(io_uring_wait_cqe_timeout(ring, &cqes[0], &timeout) == 0))
    {
      return io_uring_peek_batch_cqe(ring, &cqes[0], cqe_count);
    }
    return -1;
  }

  return count;
}

int transport_peek(uint32_t cqe_count, struct io_uring_cqe **cqes, struct io_uring *ring)
{
  int count = 0;
  if (unlikely(!(count = io_uring_peek_batch_cqe(ring, &cqes[0], cqe_count))))
  {
    return -1;
  }
  return count;
}

int transport_close_descritor(int fd)
{
  return shutdown(fd, SHUT_RDWR);
}