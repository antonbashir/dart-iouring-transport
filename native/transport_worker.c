#include "transport_common.h"
#include "transport_worker.h"
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
#include "transport_constants.h"

#define BUFFER_AVAILABLE -2
#define BUFFER_USED -1

transport_worker_t *transport_worker_initialize(transport_worker_configuration_t *configuration, int64_t id)
{
  transport_worker_t *worker = malloc(sizeof(transport_worker_t));
  if (!worker)
  {
    return NULL;
  }

  worker->id = id;
  worker->listener = transport_listener_pool_initialize();

  worker->buffer_size = configuration->buffer_size;
  worker->buffers_count = configuration->buffers_count;
  worker->buffers = malloc(sizeof(struct iovec) * configuration->buffers_count);
  worker->used_buffers = malloc(sizeof(uint64_t) * configuration->buffers_count);
  worker->used_buffers_offsets = malloc(sizeof(uint64_t) * configuration->buffers_count);
  worker->available_buffer_id = 0;

  for (size_t index = 0; index < configuration->buffers_count; index++)
  {
    void *buffer_memory = mmap(NULL, configuration->buffer_size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, 0, 0);
    if (buffer_memory == MAP_FAILED)
    {
      return NULL;
    }

    worker->buffers[index].iov_base = buffer_memory;
    worker->buffers[index].iov_len = configuration->buffer_size;
    worker->used_buffers[index] = BUFFER_AVAILABLE;
    worker->used_buffers_offsets[index] = 0;
  }

  struct io_uring *ring = malloc(sizeof(struct io_uring));
  int32_t status = io_uring_queue_init(configuration->ring_size, ring, configuration->ring_flags);
  if (status)
  {
    free(ring);
    free(worker);
    return NULL;
  }

  worker->ring = ring;

  return worker;
}

int transport_worker_select_buffer(transport_worker_t *worker)
{
  while (worker->used_buffers[worker->available_buffer_id] != BUFFER_AVAILABLE)
  {
    worker->available_buffer_id++;
    if (worker->available_buffer_id == worker->buffers_count)
    {
      worker->available_buffer_id = 0;
      if (worker->used_buffers[worker->available_buffer_id] != BUFFER_AVAILABLE)
      {
        return -1;
      }
      break;
    }
  }

  worker->used_buffers[worker->available_buffer_id] = BUFFER_USED;
  return worker->available_buffer_id;
}

int transport_worker_write(struct transport_worker *worker, int fd, int buffer_id, int64_t offset, int64_t event)
{
  struct io_uring_sqe *sqe = provide_sqe(worker->ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listener);
  worker->used_buffers[buffer_id] = fd;
  worker->used_buffers_offsets[buffer_id] = offset;
  io_uring_prep_msg_ring(sqe, channel->ring->ring_fd, fd, buffer_id | worker->id | event, 0);
  if (likely(io_uring_submit_and_wait(worker->ring, 1) != -1))
  {
    io_uring_cq_advance(worker->ring, 1);
    return 0;
  }
  return -1;
}

int transport_worker_read(struct transport_worker *worker, int fd, int buffer_id, int64_t offset, int64_t event)
{
  struct io_uring_sqe *sqe = provide_sqe(worker->ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listener);
  worker->used_buffers[buffer_id] = fd;
  worker->used_buffers_offsets[buffer_id] = offset;
  io_uring_prep_msg_ring(sqe, channel->ring->ring_fd, fd, buffer_id | worker->id | event, 0);
  if (likely(io_uring_submit_and_wait(worker->ring, 1) != -1))
  {
    io_uring_cq_advance(worker->ring, 1);
    return 0;
  }
  return -1;
}

int transport_worker_connect(struct transport_worker *worker, transport_connector_t *connector)
{
  struct io_uring_sqe *sqe = provide_sqe(worker->ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listener);
  io_uring_prep_msg_ring(sqe, channel->ring->ring_fd, 0, (intptr_t)connector | worker->id | TRANSPORT_EVENT_MESSAGE | TRANSPORT_EVENT_CONNECT, 0);
  if (likely(io_uring_submit_and_wait(worker->ring, 1) != -1))
  {
    io_uring_cq_advance(worker->ring, 1);
    return 0;
  }
  return -1;
}

int transport_worker_accept(struct transport_worker *worker, transport_acceptor_t *acceptor)
{
  struct io_uring_sqe *sqe = provide_sqe(worker->ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listener);
  io_uring_prep_msg_ring(sqe, channel->ring->ring_fd, 0, (intptr_t)acceptor | worker->id | TRANSPORT_EVENT_MESSAGE | TRANSPORT_EVENT_ACCEPT, 0);
  if (likely(io_uring_submit_and_wait(worker->ring, 1) != -1))
  {
    io_uring_cq_advance(worker->ring, 1);
    return 0;
  }
  return -1;
}

int transport_worker_close(struct transport_worker *worker)
{
  struct io_uring_sqe *sqe = provide_sqe(worker->ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listener);
  io_uring_prep_msg_ring(sqe, channel->ring->ring_fd, 0, worker->id | TRANSPORT_EVENT_MESSAGE | TRANSPORT_EVENT_CLOSE, 0);
  if (likely(io_uring_submit_and_wait(worker->ring, 1) != -1))
  {
    io_uring_cq_advance(worker->ring, 1);
    return 0;
  }
}

void transport_worker_destroy(transport_worker_t *worker)
{
  for (size_t index = 0; index < worker->buffers_count; index++)
  {
    munmap(worker->buffers[index].iov_base, worker->buffer_size);
  }
  free(worker->buffers);
  free(worker->used_buffers);
  io_uring_queue_exit(worker->ring);
  free(worker->ring);
  free(worker);
}