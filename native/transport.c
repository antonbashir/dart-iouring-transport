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
#include "transport_channel.h"
#include "transport_acceptor.h"
#include "small/include/small/rlist.h"

transport_t *transport_initialize(transport_configuration_t *transport_configuration,
                                  transport_channel_configuration_t *channel_configuration,
                                  transport_connector_configuration_t *connector_configuration,
                                  transport_acceptor_configuration_t *acceptor_configuration)
{
  transport_logger_initialize(transport_configuration->logging_port);

  transport_t *transport = malloc(sizeof(transport_t));
  if (!transport)
  {
    return NULL;
  }

  transport->acceptor_configuration = acceptor_configuration;
  transport->channel_configuration = channel_configuration;
  transport->connector_configuration = connector_configuration;
  transport->channels = transport_channel_pool_initialize();

  return transport;
}

void transport_destroy(transport_t *transport)
{
  free(transport->acceptor_configuration);
  free(transport->channel_configuration);
  free(transport->connector_configuration);
  free(transport->channels);
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

int transport_wait(uint32_t cqe_count, struct io_uring_cqe **cqes, struct io_uring *ring)
{
  int count = 0;
  if (!(count = io_uring_peek_batch_cqe(ring, &cqes[0], cqe_count)))
  {
    Dart_EnterScope();
    Dart_Isolate current = Dart_CurrentIsolate();
    Dart_ExitIsolate();
    if (likely(io_uring_wait_cqe(ring, &cqes[0]) == 0))
    {
      Dart_EnterIsolate(current);
      Dart_ExitScope();
      return io_uring_peek_batch_cqe(ring, &cqes[0], cqe_count);
    }
    Dart_EnterIsolate(current);
    Dart_ExitScope();
    return -1;
  }
  return count;
}

int transport_peek(uint32_t cqe_count, struct io_uring_cqe **cqes, struct io_uring *ring)
{
  int count = 0;
  if (!(count = io_uring_peek_batch_cqe(ring, &cqes[0], cqe_count)))
  {
    return -1;
  }
  return count;
}

int transport_close_descritor(int fd)
{
  return shutdown(fd, SHUT_RDWR);
}