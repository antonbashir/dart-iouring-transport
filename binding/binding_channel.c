#include "binding_common.h"
#include "binding_channel.h"
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
#include "binding_constants.h"

transport_channel_t *transport_channel_initialize(transport_channel_configuration_t *configuration)
{
  transport_channel_t *channel = malloc(sizeof(transport_channel_t));
  if (!channel)
  {
    return NULL;
  }

  channel->buffer_size = configuration->buffer_size;
  channel->buffers_count = configuration->buffers_count;

  channel->buffers = malloc(sizeof(struct iovec) * configuration->buffers_count);
  channel->buffers_state = malloc(sizeof(uint64_t) * configuration->buffers_count);
  channel->buffer_by_fd = malloc(sizeof(uint64_t) * configuration->buffers_count);
  channel->available_buffer_id = 0;

  for (size_t index = 0; index < configuration->buffers_count; index++)
  {
    void *buffer_memory = mmap(NULL, configuration->buffer_size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, 0, 0);
    if (buffer_memory == MAP_FAILED)
    {
      return NULL;
    }

    channel->buffers[index].iov_base = buffer_memory;
    channel->buffers[index].iov_len = configuration->buffer_size;
    channel->buffers_state[index] = 1;
  }

  struct io_uring *ring = malloc(sizeof(struct io_uring));
  int32_t status = io_uring_queue_init(configuration->ring_size, ring, configuration->ring_flags);
  if (status)
  {
    log_error("[channel]: io_urig init error = %d", status);
    free(ring);
    free(channel);
    return NULL;
  }

  channel->ring = ring;
  io_uring_register_buffers(ring, channel->buffers, configuration->buffers_count);

  log_info("[channel] initialized");
  return channel;
}

int transport_channel_allocate_buffer(transport_channel_t *channel)
{
  while (unlikely(!(channel->buffers_state[channel->available_buffer_id])))
  {
    channel->available_buffer_id++;
    if (unlikely(channel->available_buffer_id == channel->buffers_count))
    {
      channel->available_buffer_id = 0;
      if (unlikely(!(channel->buffers_state[channel->available_buffer_id])))
      {
        return -1;
      }
      break;
    }
  }

  channel->buffers_state[channel->available_buffer_id] = 0;
  return channel->available_buffer_id;
}

int transport_channel_write(struct transport_channel *channel, int fd, int buffer_id)
{
  struct io_uring_sqe *sqe = provide_sqe(channel->ring);
  channel->buffer_by_fd[fd] = buffer_id;
  io_uring_prep_write_fixed(sqe, fd, channel->buffers[buffer_id].iov_base, channel->buffers[buffer_id].iov_len, 0, buffer_id);
  io_uring_sqe_set_data64(sqe, (int64_t)(fd | TRANSPORT_PAYLOAD_WRITE));
  return io_uring_submit(channel->ring);
}

int transport_channel_read(struct transport_channel *channel, int fd, int buffer_id)
{
  struct io_uring_sqe *sqe = provide_sqe(channel->ring);
  channel->buffer_by_fd[fd] = buffer_id;
  io_uring_prep_read_fixed(sqe, fd, channel->buffers[buffer_id].iov_base, channel->buffers[buffer_id].iov_len, 0, buffer_id);
  io_uring_sqe_set_data64(sqe, (int64_t)(fd | TRANSPORT_PAYLOAD_READ));
  return io_uring_submit(channel->ring);
}

int transport_channel_handle_write(struct transport_channel *channel, int fd, size_t size)
{
  int buffer_id = channel->buffer_by_fd[fd];
  channel->buffers[buffer_id].iov_len = size;
  return buffer_id;
}

int transport_channel_handle_read(struct transport_channel *channel, int fd, size_t size)
{
  int buffer_id = channel->buffer_by_fd[fd];
  channel->buffers[buffer_id].iov_len = size;
  return buffer_id;
}

void transport_channel_complete_read_by_fd(transport_channel_t *channel, int fd)
{
  channel->buffers_state[channel->buffer_by_fd[fd]] = 1;
}

void transport_channel_complete_write_by_fd(transport_channel_t *channel, int fd)
{
  int buffer_id = channel->buffer_by_fd[fd];
  channel->buffers_state[buffer_id] = 1;
  transport_channel_read(channel, fd, buffer_id);
}

void transport_channel_complete_read_by_buffer_id(transport_channel_t *channel, int id)
{
  channel->buffers_state[id] = 1;
}

void transport_channel_complete_write_by_buffer_id(transport_channel_t *channel, int fd, int id)
{
  channel->buffers_state[id] = 1;
  transport_channel_read(channel, fd, id);
}

void transport_channel_close(transport_channel_t *channel)
{
  free(channel);
}
