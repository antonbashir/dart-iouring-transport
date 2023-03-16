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
  transport->inbound_channels = transport_channel_pool_initialize();
  transport->outbound_channels = transport_channel_pool_initialize();

  transport_info("[transport]: initialized");
  return transport;
}

void transport_shutdown(transport_t *transport)
{
  struct io_uring_sqe *sqe = provide_sqe(transport->acceptor->ring);
  io_uring_prep_nop(sqe);
  io_uring_sqe_set_data64(sqe, (uint64_t)TRANSPORT_EVENT_CLOSE);
  io_uring_submit(transport->acceptor->ring);
  transport_info("[transport]: shutdown");
}

void transport_destroy(transport_t *transport)
{
  free(transport->acceptor_configuration);
  free(transport->channel_configuration);
  free(transport->inbound_channels);
  transport_info("[transport]: destroy");
}

transport_channel_t *transport_add_inbound_channel(transport_t *transport)
{
  transport_channel_t *channel = transport_channel_initialize(transport->channel_configuration);
  transport_channel_pool_add(transport->inbound_channels, channel);
  return channel;
}

transport_channel_t *transport_add_outbound_channel(transport_t *transport)
{
  transport_channel_t *channel = transport_channel_initialize(transport->channel_configuration);
  transport_channel_pool_add(transport->outbound_channels, channel);
  return channel;
}

transport_channel_t *transport_select_outbound_channel(transport_t *transport)
{
  return transport_channel_pool_next(transport->outbound_channels);
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
    if (likely(io_uring_wait_cqe(ring, &cqes[0]) == 0))
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
  if (!(count = io_uring_peek_batch_cqe(ring, &cqes[0], cqe_count)))
  {
    return -1;
  }
  return count;
}

void transport_accept(transport_t *transport, transport_acceptor_t *acceptor)
{
  transport->acceptor = acceptor;
  struct io_uring *ring = acceptor->ring;
  transport_prepare_accept(acceptor);
  struct io_uring_cqe *cqe;
  while (true)
  {
    if (likely(io_uring_wait_cqe(ring, &cqe) == 0))
    {
      if (unlikely(cqe->user_data & TRANSPORT_EVENT_CLOSE))
      {
        io_uring_cqe_seen(ring, cqe);
        transport_channel_t *channel, *temp;
        rlist_foreach_entry_safe(channel, &transport->inbound_channels->channels, channel_pool_link, temp)
        {
          struct io_uring_sqe *sqe = provide_sqe(ring);
          io_uring_prep_msg_ring(sqe, channel->ring->ring_fd, 0, TRANSPORT_EVENT_CLOSE, 0);
        }
        io_uring_submit_and_wait(ring, transport->inbound_channels->count);
        break;
      }

      if (unlikely(cqe->res < 0))
      {
        transport_prepare_accept(acceptor);
        io_uring_cqe_seen(ring, cqe);
        continue;
      }

      if (cqe->res == 0)
      {
        io_uring_cqe_seen(ring, cqe);
        continue;
      }

      transport_channel_t *channel = transport_channel_pool_next(transport->inbound_channels);
      struct io_uring_sqe *sqe = provide_sqe(ring);
      io_uring_prep_msg_ring(sqe, channel->ring->ring_fd, cqe->res, TRANSPORT_EVENT_ACCEPT, 0);
      io_uring_submit(ring);
      io_uring_cqe_seen(ring, cqe);
      transport_prepare_accept(acceptor);
    }
  }
  transport_acceptor_shutdown(acceptor);
}

int transport_close_descritor(int fd)
{
  return shutdown(fd, SHUT_RDWR);
}

void transport_handle_dart_messages()
{
  Dart_EnterScope();
  Dart_Handle result = Dart_HandleMessage();
  if (unlikely(Dart_IsError(result)))
  {
    transport_error(Dart_GetError(result));
  }
  Dart_ExitScope();
}

void transport_test()
{
  Dart_Isolate current = Dart_CurrentIsolate();
  Dart_ExitIsolate();
  sleep(10);
  Dart_EnterIsolate(current);
}