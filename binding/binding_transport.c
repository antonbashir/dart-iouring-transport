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
#include "binding_transport.h"
#include "binding_common.h"
#include "binding_constants.h"
#include "binding_channel.h"
#include "binding_acceptor.h"
#include "small/include/small/rlist.h"

static inline int transport_acceptor_accept(struct transport_acceptor *acceptor)
{
  struct io_uring_sqe *sqe = provide_sqe(acceptor->ring);
  io_uring_prep_accept(sqe, acceptor->fd, (struct sockaddr *)&acceptor->server_address, &acceptor->server_address_length, 0);
  io_uring_sqe_set_data64(sqe, (uint64_t)TRANSPORT_PAYLOAD_ACCEPT);
  return io_uring_submit(acceptor->ring);
}

transport_channel_t *transport_add_channel(transport_t *transport)
{
  transport_channel_t *channel = transport_channel_initialize(transport->channel_configuration);
  transport->channels->add(transport->channels, channel);
  Dart_SetPerformanceMode(Dart_PerformanceMode_Throughput);
  return channel;
}

void transport_cqe_advance(struct io_uring *ring, int count)
{
  io_uring_cq_advance(ring, count);
}

struct io_uring_cqe **transport_allocate_cqes(transport_t *transport)
{
  return malloc(sizeof(struct io_uring_cqe) * transport->channel_configuration->ring_size);
}

int transport_consume(transport_t *transport, struct io_uring_cqe **cqes, struct io_uring *ring)
{
  int count = 0;
  if (!(count = io_uring_peek_batch_cqe(ring, &cqes[0], transport->channel_configuration->ring_size)))
  {
    if (likely(io_uring_wait_cqe(ring, &cqes[0]) == 0))
    {
      return io_uring_peek_batch_cqe(ring, &cqes[0], transport->channel_configuration->ring_size);
    }
    return -1;
  }

  return count;
}

void transport_accept(transport_t *transport, const char *ip, int port)
{
  transport_acceptor_t *acceptor = transport_acceptor_initialize(transport->acceptor_configuration, ip, port);
  transport->acceptor = acceptor;
  struct io_uring *ring = acceptor->ring;
  transport_acceptor_accept(acceptor);
  struct io_uring_cqe *cqe;
  while (true)
  {
    if (likely(io_uring_wait_cqe(ring, &cqe) == 0))
    {
      if (unlikely(cqe->user_data & TRANSPORT_PAYLOAD_CLOSE))
      {
        io_uring_cqe_seen(ring, cqe);
        transport_channel_t *channel, *temp;
        rlist_foreach_entry_safe(channel, &transport->channels->channels, channel_pool_link, temp)
        {
          struct io_uring_sqe *sqe = provide_sqe(ring);
          io_uring_prep_msg_ring(sqe, channel->ring->ring_fd, 0, TRANSPORT_PAYLOAD_CLOSE, 0);
        }
        io_uring_submit_and_wait(ring, transport->channels->count);
        break;
      }

      if (unlikely(cqe->res < 0))
      {
        transport_acceptor_accept(acceptor);
        io_uring_cqe_seen(ring, cqe);
        continue;
      }

      if (cqe->res == 0)
      {
        io_uring_cqe_seen(ring, cqe);
        continue;
      }

      transport_channel_t *channel = transport->channels->next(transport->channels);
      struct io_uring_sqe *sqe = provide_sqe(ring);
      io_uring_prep_msg_ring(sqe, channel->ring->ring_fd, cqe->res, TRANSPORT_PAYLOAD_ACTIVATE, 0);
      io_uring_submit(ring);
      io_uring_cqe_seen(ring, cqe);
      transport_acceptor_accept(acceptor);
    }
  }
  transport_acceptor_shutdown(acceptor);
}

int transport_close_descritor(transport_t *transport, int fd)
{
  return shutdown(fd, SHUT_RDWR);
}

transport_t *transport_initialize(transport_configuration_t *transport_configuration,
                                  transport_channel_configuration_t *channel_configuration,
                                  transport_acceptor_configuration_t *acceptor_configuration)
{
  log_set_level(transport_configuration->log_level);

  transport_t *transport = malloc(sizeof(transport_t));
  if (!transport)
  {
    return NULL;
  }

  transport->acceptor_configuration = acceptor_configuration;
  transport->channel_configuration = channel_configuration;
  transport->channels = transport_channel_pool_initialize(transport_configuration->channel_pool_mode);

  log_info("[transport]: initialized");
  return transport;
}

void transport_shutdown(transport_t *transport)
{
  struct io_uring_sqe *sqe = provide_sqe(transport->acceptor->ring);
  io_uring_prep_nop(sqe);
  io_uring_sqe_set_data64(sqe, (uint64_t)TRANSPORT_PAYLOAD_CLOSE);
  io_uring_submit(transport->acceptor->ring);
  log_info("[transport]: shutdown");
}

void transport_destroy(transport_t *transport)
{
  free(transport->acceptor_configuration);
  free(transport->channel_configuration);
  free(transport->channels);
  log_info("[transport]: destroy");
}