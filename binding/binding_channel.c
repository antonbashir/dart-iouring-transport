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
#include "fiber_channel.h"
#include "fiber.h"
#include "binding_message.h"
#include "dart/dart_api.h"

struct transport_channel_context
{
  struct io_uring *ring;
  uint32_t buffer_size;
  uint32_t buffers_count;
  struct iovec *buffers;
  int *buffers_state;
  int *buffer_by_fd;
  int available_buffer_id;
};

static inline void dart_post_pointer(void *pointer, Dart_Port port)
{
  Dart_CObject dart_object;
  dart_object.type = Dart_CObject_kInt64;
  dart_object.value.as_int64 = (int64_t)pointer;
  Dart_PostCObject(port, &dart_object);
}

static inline void dart_post_int(int32_t value, Dart_Port port)
{
  Dart_CObject dart_object;
  dart_object.type = Dart_CObject_kInt32;
  dart_object.value.as_int32 = value;
  Dart_PostCObject(port, &dart_object);
}

transport_channel_t *transport_initialize_channel(transport_t *transport,
                                                  transport_channel_configuration_t *configuration,
                                                  Dart_Port accept_port,
                                                  Dart_Port read_port,
                                                  Dart_Port write_port)
{
  transport_channel_t *channel = malloc(sizeof(transport_channel_t));
  if (!channel)
  {
    return NULL;
  }

  channel->transport = transport;
  channel->accept_port = accept_port;
  channel->read_port = read_port;
  channel->write_port = write_port;

  struct transport_channel_context *context = malloc(sizeof(struct transport_channel_context));
  channel->context = context;

  context->buffer_size = 1U << configuration->buffer_shift;
  context->buffers_count = configuration->buffers_count;

  context->buffers = malloc(sizeof(struct iovec) * configuration->buffers_count);
  context->buffers_state = malloc(sizeof(uint64_t) * configuration->buffers_count);
  context->buffer_by_fd = malloc(sizeof(uint64_t) * configuration->buffers_count);
  context->available_buffer_id = 0;

  for (size_t index = 0; index < configuration->buffers_count; index++)
  {
    void *buffer_memory = mmap(NULL, context->buffer_size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, 0, 0);
    if (buffer_memory == MAP_FAILED)
    {
      return NULL;
    }

    context->buffers[index].iov_base = buffer_memory;
    context->buffers[index].iov_len = context->buffer_size;
    context->buffers_state[index] = 1;
  }

  log_info("channel initialized");
  return channel;
}

int transport_channel_allocate_buffer(transport_channel_t *channel)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  while (unlikely(!(context->buffers_state[context->available_buffer_id])))
  {
    context->available_buffer_id++;
    if (unlikely(context->available_buffer_id == context->buffers_count))
    {
      context->available_buffer_id = 0;
      return -1;
    }
  }

  context->buffers_state[context->available_buffer_id] = 0;
  return context->available_buffer_id;
}

void transport_channel_handle_accept(struct transport_channel *channel, int fd)
{
  log_debug("channel handle accept %d", fd);
  dart_post_int(fd, channel->accept_port);
}

void transport_channel_handle_write(struct transport_channel *channel, struct io_uring_cqe *cqe)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  log_debug("channel handle write cqe res = %d", cqe->res);
  context->buffers[context->buffer_by_fd[cqe->user_data & ~TRANSPORT_PAYLOAD_ALL_FLAGS]].iov_len = cqe->res;
  dart_post_int(cqe->user_data & ~TRANSPORT_PAYLOAD_ALL_FLAGS, channel->write_port);
}

void transport_channel_handle_read(struct transport_channel *channel, struct io_uring_cqe *cqe)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  log_debug("channel read accept cqe res = %d", cqe->res);
  context->buffers[context->buffer_by_fd[cqe->user_data & ~TRANSPORT_PAYLOAD_ALL_FLAGS]].iov_len = cqe->res;
  dart_post_int(cqe->user_data & ~TRANSPORT_PAYLOAD_ALL_FLAGS, channel->read_port);
}

int transport_channel_write(struct transport_channel *channel, int fd, int buffer_id)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  struct io_uring_sqe *sqe = provide_sqe(context->ring);
  context->buffer_by_fd[fd] = buffer_id;
  io_uring_prep_write_fixed(sqe, fd, context->buffers[buffer_id].iov_base, context->buffers[buffer_id].iov_len, 0, buffer_id);
  io_uring_sqe_set_data(sqe, (void *)(fd | TRANSPORT_PAYLOAD_WRITE));
  log_debug("channel send data to ring, data size = %d", message->size);
  return io_uring_submit(context->ring);
}

int transport_channel_read(struct transport_channel *channel, int fd, int buffer_id)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  struct io_uring_sqe *sqe = provide_sqe(context->ring);
  context->buffer_by_fd[fd] = buffer_id;
  io_uring_prep_read_fixed(sqe, fd, context->buffers[buffer_id].iov_base, context->buffers[buffer_id].iov_len, 0, buffer_id);
  io_uring_sqe_set_data(sqe, (void *)(fd | TRANSPORT_PAYLOAD_READ));
  log_debug("channel receive data with ring, data size = %d", message->size);
  return io_uring_submit(context->ring);
}

struct iovec *transport_channel_get_buffer(transport_channel_t *channel, int buffer_id)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  return &context->buffers[buffer_id];
}

int transport_channel_get_buffer_by_fd(transport_channel_t *channel, int fd)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  return context->buffer_by_fd[fd];
}

void transport_channel_free_buffer(transport_channel_t *channel, int buffer_id)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  context->buffers_state[buffer_id] = 1;
}

void transport_close_channel(transport_channel_t *channel)
{
  free(channel);
}

void transport_channel_register(struct transport_channel *channel, struct io_uring *ring)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  context->ring = ring;
  io_uring_register_buffers(ring, context->buffers, context->buffers_count);
}