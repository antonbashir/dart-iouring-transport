#include <stdio.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <liburing.h>
#include <string.h>
#include <errno.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/time.h>
#include "transport_common.h"
#include "transport_constants.h"
#include "transport_channel.h"
#include "transport_worker.h"
#include "transport_acceptor.h"
#include "transport_connector.h"

transport_channel_t *transport_channel_initialize(transport_channel_configuration_t *configuration)
{
  transport_channel_t *channel = malloc(sizeof(transport_channel_t));
  if (!channel)
  {
    return NULL;
  }

  channel->workers_count = configuration->workers_count;
  channel->worker_ids = malloc(sizeof(uint64_t) * configuration->workers_count);
  channel->worker_mask = 0;
  for (size_t worker_index = 0; worker_index < channel->workers_count; worker_index++)
  {
    channel->worker_ids[worker_index] = (uint64_t)(1 << (64 - TRANSPORT_EVENT_MAX - worker_index - 1));
    channel->worker_mask |= channel->worker_ids[worker_index];
  }
  channel->workers = malloc(sizeof(intptr_t) * configuration->workers_count);

  struct io_uring *ring = malloc(sizeof(struct io_uring));
  int32_t status = io_uring_queue_init(configuration->ring_size, ring, configuration->ring_flags);
  if (status)
  {
    free(ring);
    free(channel);
    return NULL;
  }

  channel->ring = ring;
  return channel;
}

static inline transport_worker_t *transport_channel_get_worker(transport_channel_t *channel, int64_t worker_data)
{
  for (size_t worker_index = 0; worker_index < channel->workers_count; worker_index++)
  {
    if (worker_data & channel->worker_ids[worker_index])
      return (transport_worker_t *)channel->workers[worker_index];
  }
  unreachable();
}

int transport_channel_submit(transport_channel_t *channel, int worker_result, int64_t worker_data)
{
  struct io_uring_sqe *sqe = provide_sqe(channel->ring);
  if (worker_data & TRANSPORT_EVENT_READ || worker_data & TRANSPORT_EVENT_READ_CALLBACK)
  {
    transport_worker_t *worker = transport_channel_get_worker(channel, worker_data);
    int64_t buffer_id = worker_data & ~TRANSPORT_EVENT_ALL_FLAGS & ~channel->worker_mask;
    io_uring_prep_readv(sqe, worker_result, &worker->buffers[buffer_id], 1, worker->used_buffers_offsets[buffer_id]);
    io_uring_sqe_set_data64(sqe, worker_data);
    return io_uring_submit(channel->ring);
  }
  if (worker_data & TRANSPORT_EVENT_WRITE || worker_data & TRANSPORT_EVENT_WRITE_CALLBACK)
  {
    transport_worker_t *worker = transport_channel_get_worker(channel, worker_data);
    int64_t buffer_id = worker_data & ~TRANSPORT_EVENT_ALL_FLAGS & ~channel->worker_mask;
    io_uring_prep_writev(sqe, worker_result, &worker->buffers[buffer_id], 1, worker->used_buffers_offsets[buffer_id]);
    io_uring_sqe_set_data64(sqe, worker_data);
    return io_uring_submit(channel->ring);
  }
  if (worker_data & TRANSPORT_EVENT_ACCEPT)
  {
    transport_worker_t *worker = transport_channel_get_worker(channel, worker_data);
    transport_acceptor_t *acceptor = (transport_acceptor_t *)(worker_data & ~TRANSPORT_EVENT_ALL_FLAGS & ~channel->worker_mask);
    io_uring_prep_accept(sqe, acceptor->fd, (struct sockaddr *)&acceptor->server_address, &acceptor->server_address_length, 0);
    io_uring_sqe_set_data64(sqe, worker_data & TRANSPORT_EVENT_ACCEPT);
    return io_uring_submit(channel->ring);
  }
  if (worker_data & TRANSPORT_EVENT_CONNECT)
  {
    transport_worker_t *worker = transport_channel_get_worker(channel, worker_data);
    transport_connector_t *connector = (transport_connector_t *)(worker_data & ~TRANSPORT_EVENT_ALL_FLAGS & ~channel->worker_mask);
    io_uring_prep_connect(sqe, connector->fd, (struct sockaddr *)&connector->client_address, connector->client_address_length);
    io_uring_sqe_set_data64(sqe, worker_data);
    return io_uring_submit(channel->ring);
  }
  if (worker_data & TRANSPORT_EVENT_CLOSE)
  {
    transport_worker_t *worker = transport_channel_get_worker(channel, worker_data);
    // TODO: Handle
    return 0;
  }
  unreachable();
}

void transport_channel_destroy(transport_channel_t *channel)
{
  io_uring_queue_exit(channel->ring);
  free(channel->ring);
  free(channel);
}