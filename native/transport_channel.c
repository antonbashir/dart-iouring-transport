#include "transport_common.h"
#include "transport_channel.h"
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
  channel->buffer_by_fd = mh_i32_new();
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
    transport_error("[channel]: io_urig init error = %d", status);
    free(ring);
    free(channel);
    return NULL;
  }

  channel->ring = ring;
  io_uring_register_buffers(ring, channel->buffers, configuration->buffers_count);

  transport_info("[channel] initialized");
  return channel;
}

transport_channel_t *transport_channel_for_ring(transport_channel_configuration_t *configuration, struct io_uring *ring)
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
  channel->buffer_by_fd = mh_i32_new();

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

  channel->ring = ring;
  io_uring_register_buffers(ring, channel->buffers, configuration->buffers_count);

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
  struct mh_i32_node_t buffer_by_fd_node = {fd, buffer_id};
  mh_i32_put(channel->buffer_by_fd, &buffer_by_fd_node, NULL, 0);
  io_uring_prep_write_fixed(sqe, fd, channel->buffers[buffer_id].iov_base, channel->buffers[buffer_id].iov_len, 0, buffer_id);
  io_uring_sqe_set_data64(sqe, (int64_t)(fd | TRANSPORT_EVENT_WRITE));
  return io_uring_submit(channel->ring);
}

int transport_channel_read(struct transport_channel *channel, int fd, int buffer_id)
{
  struct io_uring_sqe *sqe = provide_sqe(channel->ring);
  struct mh_i32_node_t buffer_by_fd_node = {fd, buffer_id};
  mh_i32_put(channel->buffer_by_fd, &buffer_by_fd_node, NULL, 0);
  io_uring_prep_read_fixed(sqe, fd, channel->buffers[buffer_id].iov_base, channel->buffers[buffer_id].iov_len, 0, buffer_id);
  io_uring_sqe_set_data64(sqe, (int64_t)(fd | TRANSPORT_EVENT_READ));
  return io_uring_submit(channel->ring);
}

int transport_channel_write_custom_data(struct transport_channel *channel, int fd, int buffer_id, uint64_t offset, int64_t user_data)
{
  struct io_uring_sqe *sqe = provide_sqe(channel->ring);
  struct mh_i32_node_t buffer_by_fd_node = {fd, buffer_id};
  mh_i32_put(channel->buffer_by_fd, &buffer_by_fd_node, NULL, 0);
  io_uring_prep_write_fixed(sqe, fd, channel->buffers[buffer_id].iov_base, channel->buffers[buffer_id].iov_len, offset, buffer_id);
  io_uring_sqe_set_data64(sqe, user_data);
  return io_uring_submit(channel->ring);
}

int transport_channel_read_custom_data(struct transport_channel *channel, int fd, int buffer_id, uint64_t offset, int64_t user_data)
{
  struct io_uring_sqe *sqe = provide_sqe(channel->ring);
  struct mh_i32_node_t buffer_by_fd_node = {fd, buffer_id};
  mh_i32_put(channel->buffer_by_fd, &buffer_by_fd_node, NULL, 0);
  io_uring_prep_read_fixed(sqe, fd, channel->buffers[buffer_id].iov_base, channel->buffers[buffer_id].iov_len, offset, buffer_id);
  io_uring_sqe_set_data64(sqe, user_data);
  return io_uring_submit(channel->ring);
}

int transport_channel_handle_write(struct transport_channel *channel, int fd, size_t size)
{
  int buffer_id = mh_i32_node(channel->buffer_by_fd, mh_i32_find(channel->buffer_by_fd, fd, 0))->value;
  channel->buffers[buffer_id].iov_len = size;
  return buffer_id;
}

int transport_channel_handle_read(struct transport_channel *channel, int fd, size_t size)
{
  int buffer_id = mh_i32_node(channel->buffer_by_fd, mh_i32_find(channel->buffer_by_fd, fd, 0))->value;
  channel->buffers[buffer_id].iov_len = size;
  return buffer_id;
}

void transport_channel_free_buffer_by_fd(transport_channel_t *channel, int fd)
{
  channel->buffers_state[mh_i32_node(channel->buffer_by_fd, mh_i32_find(channel->buffer_by_fd, fd, 0))->value] = 1;
}

void transport_channel_free_buffer_by_id(transport_channel_t *channel, int id)
{
  channel->buffers_state[id] = 1;
}

void transport_channel_complete_write_by_fd(transport_channel_t *channel, int fd)
{
  int buffer_id = mh_i32_node(channel->buffer_by_fd, mh_i32_find(channel->buffer_by_fd, fd, 0))->value;
  channel->buffers_state[buffer_id] = 1;
  transport_channel_read(channel, fd, buffer_id);
}

void transport_channel_complete_write_by_buffer_id(transport_channel_t *channel, int fd, int id)
{
  channel->buffers_state[id] = 1;
  transport_channel_read(channel, fd, id);
}

void transport_channel_close(transport_channel_t *channel)
{
  io_uring_unregister_buffers(channel->ring);
  for (size_t index = 0; index < channel->buffers_count; index++)
  {
    munmap(channel->buffers[index].iov_base, channel->buffer_size);
  }
  free(channel->buffers);
  free(channel->buffers_state);
  mh_i32_delete(channel->buffer_by_fd);
  io_uring_queue_exit(channel->ring);
  free(channel->ring);
  free(channel);
  transport_info("[channel] closed");
}

void transport_channel_for_ring_close(transport_channel_t *channel)
{
  io_uring_unregister_buffers(channel->ring);
  for (size_t index = 0; index < channel->buffers_count; index++)
  {
    munmap(channel->buffers[index].iov_base, channel->buffer_size);
  }
  free(channel->buffers);
  free(channel->buffers_state);
  mh_i32_delete(channel->buffer_by_fd);
  free(channel);
}
