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
#include "transport_listener.h"
#include "transport_worker.h"
#include "transport_acceptor.h"
#include "transport_connector.h"

transport_listener_t *transport_listener_initialize(transport_listener_configuration_t *configuration)
{
  transport_listener_t *listener = malloc(sizeof(transport_listener_t));
  if (!listener)
  {
    return NULL;
  }

  listener->workers_count = configuration->workers_count;
  listener->worker_ids = malloc(sizeof(uint64_t) * configuration->workers_count);
  listener->worker_mask = 0;
  for (size_t worker_index = 0; worker_index < listener->workers_count; worker_index++)
  {
    listener->worker_ids[worker_index] = ((uint64_t)1 << (64 - TRANSPORT_EVENT_MAX - worker_index - 1));
    listener->worker_mask |= listener->worker_ids[worker_index];
  }
  listener->workers = malloc(sizeof(intptr_t) * configuration->workers_count);

  struct io_uring *ring = malloc(sizeof(struct io_uring));
  int32_t status = io_uring_queue_init(configuration->ring_size, ring, configuration->ring_flags);
  if (status)
  {
    free(ring);
    free(listener);
    return NULL;
  }

  struct iovec *buffers = malloc(sizeof(struct iovec *) * 1024 * configuration->workers_count);

  int buffer_index = 0;
  for (int worker_index = 0; worker_index < listener->workers; worker_index++)
  {
    transport_worker_t *worker = (transport_worker_t *)listener->workers[worker_index];
    for (int worker_buffer_index = 0; worker_buffer_index < worker->buffers_count; worker_buffer_index++)
    {
      buffers[buffer_index] = worker->buffers[worker_buffer_index];
      buffer_index++;
    }
  }
  io_uring_register_buffers(listener->ring, buffers, buffer_index);

  listener->ring = ring;
  return listener;
}

int transport_listener_get_worker_index(transport_listener_t *listener, int64_t worker_data)
{
  for (size_t worker_index = 0; worker_index < listener->workers_count; worker_index++)
  {
    if (worker_data & listener->worker_ids[worker_index])
      return worker_index;
  }
  unreachable();
}

static inline transport_worker_t *transport_listener_get_worker(transport_listener_t *listener, int64_t worker_data)
{
  for (size_t worker_index = 0; worker_index < listener->workers_count; worker_index++)
  {
    if (worker_data & listener->worker_ids[worker_index])
      return (transport_worker_t *)listener->workers[worker_index];
  }
  unreachable();
}

int transport_listener_prepare(transport_listener_t *listener, int worker_result, int64_t worker_data)
{
  struct io_uring_sqe *sqe = provide_sqe(listener->ring);
  if (worker_data & TRANSPORT_EVENT_READ || worker_data & TRANSPORT_EVENT_READ_CALLBACK)
  {
    transport_worker_t *worker = transport_listener_get_worker(listener, worker_data);
    int64_t buffer_id = worker_data & ~TRANSPORT_EVENT_ALL_FLAGS & ~listener->worker_mask;
    io_uring_prep_readv(sqe, worker_result, &worker->buffers[buffer_id], 1, worker->used_buffers_offsets[buffer_id]);
    io_uring_sqe_set_data64(sqe, worker_data);
    return 0;
  }
  if (worker_data & TRANSPORT_EVENT_WRITE || worker_data & TRANSPORT_EVENT_WRITE_CALLBACK)
  {
    transport_worker_t *worker = transport_listener_get_worker(listener, worker_data);
    int64_t buffer_id = worker_data & ~TRANSPORT_EVENT_ALL_FLAGS & ~listener->worker_mask;
    io_uring_prep_writev(sqe, worker_result, &worker->buffers[buffer_id], 1, worker->used_buffers_offsets[buffer_id]);
    io_uring_sqe_set_data64(sqe, worker_data);
    return 0;
  }
  if (worker_data & TRANSPORT_EVENT_ACCEPT)
  {
    transport_worker_t *worker = transport_listener_get_worker(listener, worker_data);
    transport_acceptor_t *acceptor = (transport_acceptor_t *)(worker_data & ~TRANSPORT_EVENT_ALL_FLAGS & ~listener->worker_mask);
    io_uring_prep_accept(sqe, acceptor->fd, (struct sockaddr *)&acceptor->server_address, &acceptor->server_address_length, 0);
    io_uring_sqe_set_data64(sqe, worker_data);
    return 0;
  }
  if (worker_data & TRANSPORT_EVENT_CONNECT)
  {
    transport_worker_t *worker = transport_listener_get_worker(listener, worker_data);
    transport_connector_t *connector = (transport_connector_t *)(worker_data & ~TRANSPORT_EVENT_ALL_FLAGS & ~listener->worker_mask);
    io_uring_prep_connect(sqe, connector->fd, (struct sockaddr *)&connector->client_address, connector->client_address_length);
    io_uring_sqe_set_data64(sqe, (uint64_t)connector->fd | worker->id | TRANSPORT_EVENT_CONNECT);
    return 0;
  }
  if (worker_data & TRANSPORT_EVENT_CLOSE)
  {
    transport_worker_t *worker = transport_listener_get_worker(listener, worker_data);
    // TODO: Handle
    return 0;
  }
  unreachable();
}

int transport_listener_submit(struct transport_listener *listener)
{
  return io_uring_submit(listener->ring);
}

void transport_listener_destroy(transport_listener_t *listener)
{
  io_uring_queue_exit(listener->ring);
  free(listener->ring);
  free(listener);
}