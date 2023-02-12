#include "binding_channel.h"
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
#include <sys/time.h>
#include "binding_common.h"
#include "binding_balancer.h"
#include "binding_message.h"
#include "fiber_channel.h"
#include "fiber.h"

struct transport_controller_context
{
  struct io_uring ring;
  struct fiber_channel *channel;
  struct transport_balancer *balancer;
  struct io_uring_buf_ring *buffer_ring;
  size_t buffer_count;
  int buffer_shift;
  unsigned char *buffer_base;
  int fd;
};

static inline size_t transport_buffer_size(struct transport_controller_context *context)
{
  return 1U << context->buffer_shift;
}

static inline unsigned char *transport_get_buffer(struct transport_controller_context *context, int id)
{
  return context->buffer_base + (id << context->buffer_shift);
}

static inline void dart_post_pointer(void *pointer, Dart_Port port)
{
  Dart_CObject dart_object;
  dart_object.type = Dart_CObject_kInt64;
  dart_object.value.as_int64 = (int64_t)pointer;
  Dart_PostCObject(port, &dart_object);
};

transport_channel_t *transport_initialize_channel(transport_t *transport,
                                                  transport_controller_t *controller,
                                                  transport_channel_configuration_t *configuration,
                                                  int fd,
                                                  Dart_Port read_port,
                                                  Dart_Port write_port)
{
  transport_channel_t *channel = smalloc(&transport->allocator, sizeof(transport_channel_t));
  if (!channel)
  {
    return NULL;
  }

  channel->controller = controller;
  channel->transport = transport;

  channel->read_port = read_port;
  channel->write_port = write_port;

  struct transport_controller_context *context = smalloc(&transport->allocator, sizeof(struct transport_controller_context));
  channel->context = context;

  int32_t status = io_uring_queue_init(configuration->ring_size, &context->ring, IORING_SETUP_SUBMIT_ALL | IORING_SETUP_COOP_TASKRUN | IORING_SETUP_CQSIZE);
  if (status)
  {
    log_error("io_urig init error: %d", status);
    free(&context->ring);
    smfree(&transport->allocator, context, sizeof(struct transport_controller_context));
    return NULL;
  }

  context->channel = fiber_channel_new(configuration->ring_size);

  size_t buffer_ring_size = (sizeof(struct io_uring_buf) + configuration->buffer_size) * configuration->buffers_count;
  void *buffer_memory = mmap(NULL, buffer_ring_size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, 0, 0);
  if (buffer_memory == MAP_FAILED)
  {
    return NULL;
  }
  context->buffer_ring = (struct io_uring_buf_ring *)buffer_memory;
  io_uring_buf_ring_init(context->buffer_ring);

  struct io_uring_buf_reg buffer_request = {
      .ring_addr = (unsigned long)context->buffer_ring,
      .ring_entries = configuration->buffers_count,
      .bgid = 0,
  };
  unsigned char *buffer_base = (unsigned char *)context->buffer_ring + sizeof(struct io_uring_buf) * configuration->buffers_count;

  if (!io_uring_register_buf_ring(&context->ring, &buffer_request, 0))
  {
    return NULL;
  }

  int buffer_index;
  for (buffer_index = 0; buffer_index < configuration->buffers_count; buffer_index++)
  {
    io_uring_buf_ring_add(context->buffer_ring,
                          transport_get_buffer(context, buffer_index),
                          configuration->buffer_size,
                          buffer_index,
                          io_uring_buf_ring_mask(configuration->buffers_count),
                          buffer_index);
  }

  io_uring_buf_ring_advance(context->buffer_ring, configuration->buffers_count);

  if (io_uring_register_files(&context->ring, &fd, 1))
  {
    return NULL;
  }

  context->balancer->add(channel);

  return channel;
}

static inline void transport_recycle_buffer(struct transport_controller_context *context, int id)
{
  io_uring_buf_ring_add(context->buffer_ring,
                        transport_get_buffer(context, id),
                        transport_buffer_size(context),
                        id,
                        io_uring_buf_ring_mask(context->buffer_count),
                        0);
  io_uring_buf_ring_advance(context->buffer_ring, 1);
}

void transport_close_channel(transport_channel_t *channel)
{
  smfree(&channel->transport->allocator, channel, sizeof(transport_channel_t));
}

int32_t transport_channel_queue_read(transport_channel_t *channel, uint64_t offset)
{
}

int32_t transport_channel_queue_write(transport_channel_t *channel, uint32_t payload_size, uint64_t offset)
{
}

void *transport_channel_prepare_read(transport_channel_t *channel)
{
}

void *transport_channel_prepare_write(transport_channel_t *channel)
{
}

int transport_channel_loop(va_list input)
{
  struct transport_controller *controller = va_arg(input, struct transport_controller *);
  struct transport_controller_context *context = (struct transport_controller_context *)controller->context;
  while (controller->active)
  {
    if (!fiber_channel_is_empty(context->channel))
    {
      struct transport_message *message;
      if (likely(fiber_channel_get(context->channel, &message)))
      {
        int id = (int)message->data;
        free(message);
        struct io_uring_sqe *sqe = io_uring_get_sqe(&context->ring);
        while (unlikely(sqe == NULL))
        {
          io_uring_submit(&context->ring);
          fiber_sleep(0);
          sqe = io_uring_get_sqe(&context->ring);
        }
        io_uring_prep_recvmsg_multishot(sqe, id, &ctx->msg, MSG_TRUNC);
        sqe->flags |= IOSQE_FIXED_FILE;
        sqe->flags |= IOSQE_BUFFER_SELECT;
        sqe->buf_group = 0;
        io_uring_sqe_set_data64(sqe, context->buffer_count + 1);
        io_uring_submit(&context->ring);
      }
    }

    int count = 0;
    unsigned int head;
    struct io_uring_cqe *cqe;
    io_uring_for_each_cqe(&context->ring, head, cqe)
    {
      ++count;
      if (unlikely(cqe->res < 0 || !cqe->user_data))
      {
        if (cqe->user_data)
        {
          free((void *)cqe->user_data);
        }
        continue;
      }
      int id = cqe->res;
      struct io_uring_sqe *sqe = io_uring_get_sqe(&context->ring);
      while (unlikely(sqe == NULL))
      {
        fiber_sleep(0);
      }
      struct transport_channel *channel = context->balancer->next();
      io_uring_prep_msg_ring(sqe, channel->ring.ring_fd, sizeof(id), id, 0);
      io_uring_sqe_set_data(sqe, 1);
      io_uring_submit(&context->ring);
    }
    io_uring_cq_advance(&context->ring, count);
    fiber_sleep(0);
  }
  return 0;
}