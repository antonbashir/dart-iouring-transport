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

struct transport_channel_message
{
  void *data;
  size_t size;
  int fd;
  int flags;
};

struct transport_channel_context
{
  struct fiber_channel *channel;
  struct transport_balancer *balancer;
  struct io_uring_buf_ring *buffer_ring;
  size_t buffers_count;
  uint32_t buffer_shift;
  unsigned char *buffer_base;
};

static inline size_t transport_buffer_size(struct transport_channel_context *context)
{
  return 1U << context->buffer_shift;
}

static inline unsigned char *transport_get_buffer(struct transport_channel_context *context, int id)
{
  return context->buffer_base + (id << context->buffer_shift);
}

static inline void transport_channel_recycle_buffer(struct transport_channel_context *context, int id)
{
  log_info("channel recycle buffer");
  io_uring_buf_ring_add(context->buffer_ring,
                        transport_get_buffer(context, id),
                        transport_buffer_size(context),
                        id,
                        io_uring_buf_ring_mask(context->buffers_count),
                        0);
  io_uring_buf_ring_advance(context->buffer_ring, 1);
}

static inline void dart_post_pointer(void *pointer, Dart_Port port)
{
  Dart_CObject dart_object;
  dart_object.type = Dart_CObject_kInt64;
  dart_object.value.as_int64 = (int64_t)pointer;
  Dart_PostCObject(port, &dart_object);
};

static inline void transport_channel_setup_buffers(transport_channel_configuration_t *configuration, struct transport_channel *channel, struct transport_channel_context *context)
{
  context->buffer_shift = configuration->buffer_shift;
  size_t buffer_ring_size = (sizeof(struct io_uring_buf) + transport_buffer_size(context)) * configuration->buffers_count;
  void *buffer_memory = mmap(NULL, buffer_ring_size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (buffer_memory == MAP_FAILED)
  {
    return;
  }
  context->buffer_ring = (struct io_uring_buf_ring *)buffer_memory;
  context->buffer_base = (unsigned char *)(context->buffer_ring + sizeof(struct io_uring_buf) * configuration->buffers_count);

  struct io_uring_buf_reg buffer_request = {
      .ring_addr = (unsigned long)context->buffer_ring,
      .ring_entries = configuration->buffers_count,
      .bgid = 0,
  };

  int result = io_uring_register_buf_ring(&channel->ring, &buffer_request, 0);
  if (result)
  {
    log_error("ring register buffer failed: %d", result);
    return;
  }

  io_uring_buf_ring_init(context->buffer_ring);
  int buffer_index;
  for (buffer_index = 0; buffer_index < configuration->buffers_count; buffer_index++)
  {
    io_uring_buf_ring_add(context->buffer_ring,
                          transport_get_buffer(context, buffer_index),
                          transport_buffer_size(context),
                          buffer_index,
                          io_uring_buf_ring_mask(configuration->buffers_count),
                          buffer_index);
  }

  io_uring_buf_ring_advance(context->buffer_ring, configuration->buffers_count);
}

transport_channel_t *transport_initialize_channel(transport_t *transport,
                                                  transport_controller_t *controller,
                                                  transport_channel_configuration_t *configuration,
                                                  Dart_Port read_port,
                                                  Dart_Port write_port,
                                                  Dart_Port accept_port,
                                                  Dart_Port connect_port)
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
  channel->accept_port = accept_port;
  channel->connect_port = connect_port;

  struct transport_channel_context *context = smalloc(&transport->allocator, sizeof(struct transport_channel_context));
  channel->context = context;

  int32_t status = io_uring_queue_init(configuration->ring_size, &channel->ring, 0);
  if (status)
  {
    log_error("io_urig init error: %d", status);
    free(&channel->ring);
    smfree(&transport->allocator, context, sizeof(struct transport_channel_context));
    return NULL;
  }

  transport_channel_setup_buffers(configuration, channel, context);

  context->channel = fiber_channel_new(configuration->ring_size);
  context->balancer = (struct transport_balancer *)controller->balancer;
  context->balancer->add(context->balancer, channel);

  struct transport_message *message = malloc(sizeof(struct transport_message));
  message->action = TRANSPORT_ACTION_ADD_CHANNEL;
  message->data = (void *)channel;
  transport_controller_send(channel->controller, message);

  log_info("channel initialized");
  return channel;
}

void transport_close_channel(transport_channel_t *channel)
{
  smfree(&channel->transport->allocator, channel, sizeof(transport_channel_t));
}

static inline int transport_channel_select_buffer(struct transport_channel *channel, struct transport_channel_context *context, int fd)
{
  struct io_uring_sqe *sqe = io_uring_get_sqe(&channel->ring);
  while (unlikely(sqe == NULL))
  {
    io_uring_submit(&channel->ring);
    fiber_sleep(0);
    sqe = io_uring_get_sqe(&channel->ring);
  }
  io_uring_prep_recv(sqe, fd, NULL, transport_buffer_size(context), 0);
  io_uring_sqe_set_data64(sqe, (uint64_t)(fd | TRANSPORT_PAYLOAD_READ));
  sqe->flags |= IOSQE_BUFFER_SELECT;
  sqe->buf_group = 0;
  io_uring_submit(&channel->ring);
  log_info("channel select buffers");
  return 0;
}

int32_t transport_channel_send(transport_channel_t *channel, void *data, size_t size, int fd)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  struct transport_message *message = malloc(sizeof(struct transport_message));
  message->action = TRANSPORT_ACTION_SEND;
  message->channel = context->channel;
  struct transport_channel_message *channel_message = malloc(sizeof(struct transport_channel_message));
  channel_message->data = data;
  channel_message->size = size;
  channel_message->fd = fd;
  message->data = channel_message;
  return transport_controller_send(channel->controller, message) ? 0 : -1;
}

int transport_channel_loop(va_list input)
{
  struct transport_channel *channel = va_arg(input, struct transport_channel *);
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  log_info("channel fiber started");
  channel->active = true;
  while (channel->active)
  {
    if (!fiber_channel_is_empty(context->channel))
    {
      void *message;
      if (likely(fiber_channel_get(context->channel, &message) == 0))
      {
        struct transport_channel_message *channel_message = (struct transport_channel_message *)((struct transport_message *)message)->data;
        free(message);
        struct io_uring_sqe *sqe = io_uring_get_sqe(&channel->ring);
        while (unlikely(sqe == NULL))
        {
          io_uring_submit(&channel->ring);
          fiber_sleep(0);
          sqe = io_uring_get_sqe(&channel->ring);
        }
        io_uring_prep_send(sqe, channel_message->fd, channel_message->data, channel_message->size, 0);
        io_uring_sqe_set_data64(sqe, (uint64_t)((intptr_t)channel_message | TRANSPORT_PAYLOAD_WRITE));
        io_uring_submit(&channel->ring);
        log_info("channel send data to ring, data size = %d", channel_message->size);
      }
    }

    int count = 0;
    unsigned int head;
    struct io_uring_cqe *cqe;
    io_uring_for_each_cqe(&channel->ring, head, cqe)
    {
      log_info("channel process cqe with result %d and user_data %d", cqe->res, cqe->user_data);
      ++count;

      if (cqe->res < 0)
      {
        fiber_sleep(0.1);
        continue;
      }

      if ((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_READ))
      {
        if (cqe->flags & IORING_CQE_F_BUFFER)
        {
          int buffer_id = cqe->flags >> 16;
          int fd = cqe->user_data & ~TRANSPORT_PAYLOAD_ALL_FLAGS;
          void *payload = transport_get_buffer(context, buffer_id);
          if (payload)
          {
            transport_payload_t *payload = malloc(sizeof(transport_payload_t));
            uint32_t size = cqe->res;
            void *output = malloc(size);
            memcpy(output, payload, size);
            payload->data = output;
            payload->size = size;
            payload->fd = fd;
            log_info("channel send read data to dart, data size = %d", size);
            dart_post_pointer(payload, channel->read_port);
          }
          transport_channel_recycle_buffer(context, buffer_id);
        }
        continue;
      }

      if ((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_WRITE))
      {
        struct transport_channel_message *channel_message = (struct transport_channel_message *)(cqe->user_data & ~TRANSPORT_PAYLOAD_ALL_FLAGS);
        void *payload = channel_message->data;
        if (payload)
        {
          transport_payload_t *payload = malloc(sizeof(transport_payload_t));
          uint32_t size = cqe->res;
          void *output = malloc(size);
          memcpy(output, payload, size);
          payload->data = output;
          payload->size = size;
          payload->fd = channel_message->fd;
          log_info("channel send write data to dart, data size = %d", size);
          dart_post_pointer(payload, channel->read_port);
        }
        free(channel_message->data);
        free(channel_message);
        transport_channel_select_buffer(channel, context, channel_message->fd);
        continue;
      }

      if ((uint64_t)(cqe->user_data & (TRANSPORT_PAYLOAD_ACCEPT | TRANSPORT_PAYLOAD_CONNECT)))
      {
        log_info("channel register socket");
        if (io_uring_register_files(&channel->ring, &cqe->res, 1))
        {
          log_error("channel unable to register socket");
          continue;
        }
        transport_channel_select_buffer(channel, context, cqe->res);
        continue;
      }
    }
    io_uring_cq_advance(&channel->ring, count);
    fiber_sleep(0);
  }
  return 0;
}