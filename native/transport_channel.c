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

#define BUFFER_AVAILABLE -2
#define BUFFER_USED -1

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
  channel->used_buffers = malloc(sizeof(uint64_t) * configuration->buffers_count);
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
    channel->used_buffers[index] = BUFFER_AVAILABLE;
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

int transport_channel_allocate_buffer(transport_channel_t *channel)
{
  while (unlikely(channel->used_buffers[channel->available_buffer_id] != BUFFER_AVAILABLE))
  {
    channel->available_buffer_id++;
    if (unlikely(channel->used_buffers[channel->available_buffer_id] != BUFFER_AVAILABLE))
    {
      channel->available_buffer_id = 0;
      if (unlikely(channel->used_buffers[channel->available_buffer_id] != BUFFER_AVAILABLE))
      {
        return -1;
      }
      break;
    }
  }

  channel->used_buffers[channel->available_buffer_id] = BUFFER_USED;
  return channel->available_buffer_id;
}

int transport_channel_write(struct transport_channel *channel, int fd, int buffer_id, int64_t offset, int64_t event)
{
  struct io_uring_sqe *sqe = provide_sqe(channel->ring);
  channel->used_buffers[buffer_id] = fd;
  io_uring_prep_write_fixed(sqe, fd, channel->buffers[buffer_id].iov_base, channel->buffers[buffer_id].iov_len, offset, buffer_id);
  io_uring_sqe_set_data64(sqe, (int64_t)(buffer_id | event));
  return io_uring_submit(channel->ring);
}

int transport_channel_read(struct transport_channel *channel, int fd, int buffer_id, int64_t offset, int64_t event)
{
  struct io_uring_sqe *sqe = provide_sqe(channel->ring);
  channel->used_buffers[buffer_id] = fd;
  io_uring_prep_read_fixed(sqe, fd, channel->buffers[buffer_id].iov_base, channel->buffers[buffer_id].iov_len, offset, buffer_id);
  io_uring_sqe_set_data64(sqe, (int64_t)(buffer_id | event));
  return io_uring_submit(channel->ring);
}

int transport_channel_connect(struct transport_channel *channel, int fd, const char *ip, int port)
{
  struct io_uring_sqe *sqe = provide_sqe(channel->ring);
  struct sockaddr_in *address = malloc(sizeof(struct sockaddr_in));
  memset(address, 0, sizeof(*address));
  address->sin_addr.s_addr = inet_addr(ip);
  address->sin_port = htons(port);
  address->sin_family = AF_INET;
  io_uring_prep_connect(sqe, fd, (struct sockaddr *)address, sizeof(*address));
  io_uring_sqe_set_data64(sqe, (int64_t)(fd | TRANSPORT_EVENT_CONNECT));
  return io_uring_submit(channel->ring);
}

void transport_channel_close(transport_channel_t *channel)
{
  io_uring_unregister_buffers(channel->ring);
  for (size_t index = 0; index < channel->buffers_count; index++)
  {
    munmap(channel->buffers[index].iov_base, channel->buffer_size);
  }
  free(channel->buffers);
  free(channel->used_buffers);
  io_uring_queue_exit(channel->ring);
  free(channel->ring);
  free(channel);
  transport_info("[channel] closed");
}