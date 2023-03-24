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

transport_worker_t *transport_worker_initialize(transport_worker_configuration_t *configuration, uint8_t id)
{
  transport_worker_t *worker = malloc(sizeof(transport_worker_t));
  if (!worker)
  {
    return NULL;
  }

  worker->id = id;
  worker->listeners = transport_listener_pool_initialize();
  worker->buffer_size = configuration->buffer_size;
  worker->buffers_count = configuration->buffers_count;
  worker->buffer_shift = configuration->buffer_size * id;
  worker->buffers = malloc(sizeof(struct iovec) * configuration->buffers_count);
  worker->used_buffers = malloc(sizeof(int) * configuration->buffers_count);
  worker->used_buffers_offsets = malloc(sizeof(uint64_t) * configuration->buffers_count);
  worker->used_acceptors = mh_i32_new();
  worker->used_clients = mh_i32_new();

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
  int buffer_id = 0;
  while (worker->used_buffers[buffer_id] != BUFFER_AVAILABLE)
  {
    if (++buffer_id == worker->buffers_count)
    {
      return -1;
    }
  }

  worker->used_buffers[buffer_id] = BUFFER_USED;
  return buffer_id;
}

static inline transport_listener_t *transport_listener_pool_next(transport_listener_pool_t *pool)
{
  if (unlikely(!pool->next_listener))
  {
    pool->next_listener = pool->listener.next;
    pool->next_listener_index = 0;
    return rlist_entry(pool->next_listener, transport_listener_t, listener_pool_link);
  }
  if (pool->next_listener_index + 1 == pool->count)
  {
    pool->next_listener = pool->listener.next;
    pool->next_listener_index = 0;
    return rlist_entry(pool->next_listener, transport_listener_t, listener_pool_link);
  }
  pool->next_listener = pool->next_listener->next;
  pool->next_listener_index++;
  return rlist_entry(pool->next_listener, transport_listener_t, listener_pool_link);
}

int32_t transport_worker_get_fd(uint64_t data)
{
  return (int32_t)((data >> 24) & 0xffffffff);
}

uint16_t transport_worker_get_buffer_index(transport_worker_t *worker, uint64_t data)
{
  return ((int16_t)((data >> 24) & 0xffff)) - worker->buffer_shift;
}

int transport_worker_write(transport_worker_t *worker, int32_t fd, int16_t buffer_id, uint64_t offset, uint16_t event)
{
  struct io_uring_sqe *sqe = provide_sqe(worker->ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  worker->used_buffers[buffer_id] = fd;
  worker->used_buffers_offsets[buffer_id] = offset;
  uint64_t data = ((uint64_t)(buffer_id + worker->buffer_shift) << 24) | ((uint64_t)worker->id << 16) | ((uint64_t)TRANSPORT_EVENT_INTERNAL | event);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, fd, data, 0);
  return io_uring_submit(worker->ring);
}

int transport_worker_read(transport_worker_t *worker, int32_t fd, int16_t buffer_id, uint64_t offset, uint16_t event)
{
  struct io_uring_sqe *sqe = provide_sqe(worker->ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  worker->used_buffers[buffer_id] = fd;
  worker->used_buffers_offsets[buffer_id] = offset;
  uint64_t data = ((uint64_t)(buffer_id + worker->buffer_shift) << 24) | ((uint64_t)worker->id << 16) | ((uint64_t)TRANSPORT_EVENT_INTERNAL | event);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, fd, data, 0);
  return io_uring_submit(worker->ring);
}

int transport_worker_connect(transport_worker_t *worker, transport_client_t *client)
{
  struct io_uring_sqe *sqe = provide_sqe(worker->ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  uint32_t result = ((uint32_t)worker->id << 16) | ((uint32_t)TRANSPORT_EVENT_INTERNAL | TRANSPORT_EVENT_CONNECT);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, result, (intptr_t)client, 0);
  return io_uring_submit(worker->ring);
}

int transport_worker_accept(transport_worker_t *worker, transport_acceptor_t *acceptor)
{
  struct io_uring_sqe *sqe = provide_sqe(worker->ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  uint32_t result = ((uint32_t)worker->id << 16) | (((uint32_t)TRANSPORT_EVENT_INTERNAL | TRANSPORT_EVENT_ACCEPT));
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, result, (intptr_t)acceptor, 0);
  return io_uring_submit(worker->ring);
}

int transport_worker_close(transport_worker_t *worker)
{
  struct io_uring_sqe *sqe = provide_sqe(worker->ring);
  transport_listener_t *listener = transport_listener_pool_next(worker->listeners);
  uint64_t data = ((uint64_t)worker->id << 16) | ((uint64_t)TRANSPORT_EVENT_INTERNAL | TRANSPORT_EVENT_CLOSE);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, 0, data, 0);
  return io_uring_submit(worker->ring);
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
  mh_i32_delete(worker->used_acceptors);
  mh_i32_delete(worker->used_clients);
  free(worker);
}