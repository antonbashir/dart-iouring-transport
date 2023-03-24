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
#include "transport_client.h"

transport_listener_t *transport_listener_initialize(transport_listener_configuration_t *configuration)
{
  transport_listener_t *listener = malloc(sizeof(transport_listener_t));
  if (!listener)
  {
    return NULL;
  }

  listener->workers_count = configuration->workers_count;
  listener->buffers_count = configuration->buffers_count;
  listener->buffer_size = configuration->buffer_size;
  listener->workers = malloc(sizeof(intptr_t) * configuration->workers_count);
  listener->buffers = malloc(sizeof(struct iovec) * listener->buffers_count * listener->workers_count);

  struct io_uring *ring = malloc(sizeof(struct io_uring));
  int32_t status = io_uring_queue_init(configuration->ring_size, ring, configuration->ring_flags);
  if (status)
  {
    free(ring);
    free(listener);
    return NULL;
  }

  listener->ring = ring;
  return listener;
}

int transport_listener_register_buffers(transport_listener_t *listener)
{
  int buffer_index = 0;
  for (int worker_index = 0; worker_index < listener->workers_count; worker_index++)
  {
    transport_worker_t *worker = (transport_worker_t *)listener->workers[worker_index];
    for (int worker_buffer_index = 0; worker_buffer_index < worker->buffers_count; worker_buffer_index++)
    {
      void *buffer_memory = mmap(NULL, worker->buffer_size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, 0, 0);
      if (buffer_memory == MAP_FAILED)
      {
        return -1;
      }

      listener->buffers[buffer_index].iov_base = buffer_memory;
      listener->buffers[buffer_index].iov_len = worker->buffer_size;
      worker->buffers[worker_buffer_index] = listener->buffers[buffer_index];
      buffer_index++;
    }
  }
  return io_uring_register_buffers(listener->ring, listener->buffers, buffer_index);
}

static inline transport_worker_t *transport_listener_get_worker_from_data(transport_listener_t *listener, uint64_t data)
{
  return (transport_worker_t *)listener->workers[(uint8_t)((data >> 16) & 0xff)];
}

static inline transport_worker_t *transport_listener_get_worker_from_result(transport_listener_t *listener, uint32_t result)
{
  return (transport_worker_t *)listener->workers[(uint8_t)((result >> 16) & 0xff)];
}

static inline uint16_t transport_listener_get_buffer_id(int64_t data)
{
  return (uint16_t)((data >> 24) & 0xffff);
}

int transport_listener_prepare_by_result(transport_listener_t *listener, uint32_t result, uint64_t data)
{
  struct io_uring_sqe *sqe = provide_sqe(listener->ring);
  uint16_t event = (uint16_t)(result & 0xffff);
  if (event & TRANSPORT_EVENT_ACCEPT)
  {
    transport_worker_t *worker = transport_listener_get_worker_from_result(listener, result);
    transport_acceptor_t *acceptor = (transport_acceptor_t *)data;
    uint64_t new_data = ((uint64_t)(acceptor->fd) << 24) | (worker->packed_id) | ((uint64_t)TRANSPORT_EVENT_ACCEPT);
    io_uring_prep_accept(sqe, acceptor->fd, (struct sockaddr *)&acceptor->server_address, &acceptor->server_address_length, 0);
    io_uring_sqe_set_data64(sqe, new_data);
    return 0;
  }
  if (event & TRANSPORT_EVENT_CONNECT)
  {
    transport_worker_t *worker = transport_listener_get_worker_from_result(listener, result);
    transport_client_t *client = (transport_client_t *)data;
    uint64_t new_data = ((uint64_t)(client->fd) << 24) | (worker->packed_id) | ((uint64_t)TRANSPORT_EVENT_CONNECT);
    io_uring_prep_connect(sqe, client->fd, (struct sockaddr *)&client->client_address, client->client_address_length);
    io_uring_sqe_set_data64(sqe, new_data);
    return 0;
  }
  unreachable();
}

int transport_listener_prepare_by_data(transport_listener_t *listener, uint32_t result, uint64_t data)
{
  struct io_uring_sqe *sqe = provide_sqe(listener->ring);
  uint16_t event = (uint16_t)(data & 0xffff);
  if (likely(event & (TRANSPORT_EVENT_READ | TRANSPORT_EVENT_READ_CALLBACK)))
  {
    transport_worker_t *worker = transport_listener_get_worker_from_data(listener, data);
    uint16_t buffer_id = transport_listener_get_buffer_id(data);
    struct iovec buffer = listener->buffers[buffer_id];
    io_uring_prep_read_fixed(sqe, result, buffer.iov_base, buffer.iov_len, worker->used_buffers_offsets[buffer_id - worker->buffer_shift], buffer_id);
    io_uring_sqe_set_data64(sqe, data);
    return 0;
  }
  if (likely(event & (TRANSPORT_EVENT_WRITE | TRANSPORT_EVENT_WRITE_CALLBACK)))
  {
    transport_worker_t *worker = transport_listener_get_worker_from_data(listener, data);
    uint16_t buffer_id = transport_listener_get_buffer_id(data);
    struct iovec buffer = listener->buffers[buffer_id];
    io_uring_prep_write_fixed(sqe, result, buffer.iov_base, buffer.iov_len, worker->used_buffers_offsets[buffer_id - worker->buffer_shift], buffer_id);
    io_uring_sqe_set_data64(sqe, data);
    return 0;
  }

  if (event & TRANSPORT_EVENT_CLOSE)
  {
    transport_worker_t *worker = transport_listener_get_worker_from_data(listener, data);
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
  for (size_t index = 0; index < listener->buffers_count; index++)
  {
    munmap(listener->buffers[index].iov_base, listener->buffer_size);
  }

  io_uring_unregister_buffers(listener->ring);
  io_uring_queue_exit(listener->ring);
  free(listener->ring);
  free(listener);
}