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
#include "binding_balancer.h"
#include "binding_message.h"
#include "dart/dart_api.h"

static volatile uint32_t next_id = 0;

struct transport_channel_context
{
  uint32_t id;
  struct fiber_channel *send_channel;
  struct fiber_channel *receive_channel;
  struct transport_balancer *balancer;

  uint32_t buffer_size;

  struct mempool write_buffers;
  struct mempool read_buffers;
  struct mempool payloads;
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

static inline void transport_channel_setup_buffers(transport_channel_configuration_t *configuration, struct transport_channel *channel, struct transport_channel_context *context)
{
  context->buffer_size = 1U << configuration->buffer_shift;
  mempool_create(&context->write_buffers, &channel->transport->cache, context->buffer_size);
  mempool_create(&context->read_buffers, &channel->transport->cache, context->buffer_size);
  mempool_create(&context->payloads, &channel->transport->cache, sizeof(transport_payload_t));
}

transport_channel_t *transport_initialize_channel(transport_t *transport,
                                                  transport_controller_t *controller,
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

  channel->controller = controller;
  channel->transport = transport;

  channel->accept_port = accept_port;
  channel->read_port = read_port;
  channel->write_port = write_port;

  struct transport_channel_context *context = malloc(sizeof(struct transport_channel_context));
  channel->context = context;
  channel->id = ++next_id;

  int32_t status = io_uring_queue_init(configuration->ring_size, &channel->ring, 0);
  if (status)
  {
    log_error("io_urig init error: %d", status);
    free(&channel->ring);
    free(context);
    return NULL;
  }

  transport_channel_setup_buffers(configuration, channel, context);

  context->send_channel = fiber_channel_new(1);
  context->receive_channel = fiber_channel_new(1);
  context->balancer = (struct transport_balancer *)controller->balancer;
  context->balancer->add(context->balancer, channel);

  struct transport_message *message = malloc(sizeof(struct transport_message));
  message->action = TRANSPORT_ACTION_ADD_CHANNEL;
  message->data = (void *)channel;
  transport_controller_send(channel->controller, message);

  log_info("channel initialized");
  return channel;
}

void transport_channel_accept(struct transport_channel *channel, int fd)
{
  log_debug("channel handle accept %d", fd);
  dart_post_int(fd, channel->accept_port);
}

transport_payload_t *transport_channel_allocate_write_payload(transport_channel_t *channel, int fd)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  transport_payload_t *payload = mempool_alloc(&context->payloads);
  payload->data = mempool_alloc(&context->write_buffers);
  payload->size = context->buffer_size;
  payload->fd = fd;
  return payload;
}

int32_t transport_channel_receive(transport_channel_t *channel, int fd)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  struct transport_message *message = malloc(sizeof(struct transport_message));
  message->action = TRANSPORT_ACTION_SEND;
  message->channel = context->receive_channel;
  transport_payload_t *payload = mempool_alloc(&context->payloads);
  payload->data = mempool_alloc(&context->read_buffers);
  payload->size = context->buffer_size;
  payload->fd = fd;
  message->data = payload;
  return transport_controller_send(channel->controller, message) ? 0 : -1;
}

int32_t transport_channel_send(transport_channel_t *channel, transport_payload_t *payload)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  struct transport_message *message = malloc(sizeof(struct transport_message));
  message->action = TRANSPORT_ACTION_SEND;
  message->channel = context->send_channel;
  message->data = payload;
  return transport_controller_send(channel->controller, message) ? 0 : -1;
}

static inline void transport_channel_handle_read_cqe(struct transport_channel *channel, struct transport_channel_context *context, struct io_uring_cqe *cqe)
{
  log_debug("channel read accept cqe res = %d", cqe->res);
  transport_payload_t *payload = (transport_payload_t *)(cqe->user_data & ~TRANSPORT_PAYLOAD_ALL_FLAGS);
  payload->size = cqe->res;
  log_debug("channel send read data to dart, data size = %d", payload->size);
  dart_post_pointer(payload, channel->read_port);
}

static inline void transport_channel_handle_write_cqe(struct transport_channel *channel, struct transport_channel_context *context, struct io_uring_cqe *cqe)
{
  log_debug("channel handle write cqe res = %d", cqe->res);
  transport_payload_t *payload = (transport_payload_t *)(cqe->user_data & ~TRANSPORT_PAYLOAD_ALL_FLAGS);
  payload->size = cqe->res;
  log_debug("channel send write data to dart, data size = %d", payload->size);
  dart_post_pointer(payload, channel->write_port);
}

int transport_channel_send_loop(va_list input)
{
  struct transport_channel *channel = va_arg(input, struct transport_channel *);
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  log_info("channel send fiber started");
  while (channel->active)
  {
    void *message;
    if (likely(fiber_channel_get(context->send_channel, &message) == 0))
    {
      transport_payload_t *payload = (transport_payload_t *)((struct transport_message *)message)->data;
      free(message);
      struct io_uring_sqe *sqe = provide_sqe(&channel->ring);
      io_uring_prep_send(sqe, payload->fd, payload->data, payload->size, 0);
      io_uring_sqe_set_data64(sqe, (uint64_t)((intptr_t)payload | TRANSPORT_PAYLOAD_WRITE));
      log_debug("channel send data to ring, data size = %d", payload->size);
      int count = 0;
      struct io_uring_cqe *cqe;
      struct __kernel_timespec ts = {
          .tv_sec = 0,
          .tv_nsec = 1000,
      };
      if (io_uring_submit_and_wait_timeout(&channel->ring, &cqe, 1, &ts, NULL) > 0)
      {
        unsigned int head;
        io_uring_for_each_cqe(&channel->ring, head, cqe)
        {
          log_debug("channel %d process cqe with result '%s' and user_data %d", channel->id, cqe->res < 0 ? strerror(-cqe->res) : "ok", cqe->user_data);
          ++count;
          if (cqe->res < 0)
          {
            log_error("channel %d process cqe with result '%s' and user_data %d", channel->id, strerror(-cqe->res), cqe->user_data);
            continue;
          }

          if ((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_READ))
          {
            transport_channel_handle_read_cqe(channel, context, cqe);
            continue;
          }

          if ((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_WRITE))
          {
            transport_channel_handle_write_cqe(channel, context, cqe);
            continue;
          }
        }
        io_uring_cq_advance(&channel->ring, count);
      }
    }
  }
  return 0;
}

int transport_channel_receive_loop(va_list input)
{
  struct transport_channel *channel = va_arg(input, struct transport_channel *);
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  log_info("channel receive fiber started");
  while (channel->active)
  {
    void *message;
    if (likely(fiber_channel_get(context->receive_channel, &message) == 0))
    {
      transport_payload_t *payload = (transport_payload_t *)((struct transport_message *)message)->data;
      free(message);
      struct io_uring_sqe *sqe = provide_sqe(&channel->ring);
      io_uring_prep_read(sqe, payload->fd, payload->data, payload->size, 0);
      io_uring_sqe_set_data64(sqe, (uint64_t)((intptr_t)payload | TRANSPORT_PAYLOAD_READ));
      log_debug("channel receive data with ring, data size = %d", payload->size);
      int count = 0;
      struct io_uring_cqe *cqe;
      struct __kernel_timespec ts = {
          .tv_sec = 0,
          .tv_nsec = 1000,
      };
      if (io_uring_submit_and_wait_timeout(&channel->ring, &cqe, 1, &ts, NULL) > 0)
      {
        unsigned int head;
        io_uring_for_each_cqe(&channel->ring, head, cqe)
        {
          log_debug("channel %d process cqe with result '%s' and user_data %d", channel->id, cqe->res < 0 ? strerror(-cqe->res) : "ok", cqe->user_data);
          ++count;
          if (cqe->res < 0)
          {
            log_error("channel %d process cqe with result '%s' and user_data %d", channel->id, strerror(-cqe->res), cqe->user_data);
            continue;
          }

          if ((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_READ))
          {
            transport_channel_handle_read_cqe(channel, context, cqe);
            continue;
          }

          if ((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_WRITE))
          {
            transport_channel_handle_write_cqe(channel, context, cqe);
            continue;
          }
        }
        io_uring_cq_advance(&channel->ring, count);
      }
    }
  }
  return 0;
}

int transport_channel_consume_loop(va_list input)
{
  struct transport_channel *channel = va_arg(input, struct transport_channel *);
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  struct io_uring *ring = &channel->ring;
  log_info("channel fiber consume started");
  while (likely(channel->active))
  {
    int count = 0;
    struct io_uring_cqe *cqe;
    unsigned int head;
    io_uring_for_each_cqe(ring, head, cqe)
    {
      log_debug("channel %d process cqe with result '%s' and user_data %d", channel->id, cqe->res < 0 ? strerror(-cqe->res) : "ok", cqe->user_data);
      ++count;
      if (cqe->res < 0)
      {
        log_error("channel %d process cqe with result '%s' and user_data %d", channel->id, strerror(-cqe->res), cqe->user_data);
        continue;
      }

      if ((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_READ))
      {
        transport_channel_handle_read_cqe(channel, context, cqe);
        continue;
      }

      if ((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_WRITE))
      {
        transport_channel_handle_write_cqe(channel, context, cqe);
        continue;
      }
    }

    io_uring_cq_advance(ring, count);
  }
  return 0;
}

int transport_channel_loop(va_list input)
{
  struct transport_channel *channel = va_arg(input, struct transport_channel *);
  log_info("channel fiber started");
  channel->active = true;

  struct fiber *receive = fiber_new("receive", transport_channel_receive_loop);
  struct fiber *send = fiber_new("send", transport_channel_send_loop);
  struct fiber *consume = fiber_new("consume", transport_channel_consume_loop);

  fiber_set_joinable(receive, true);
  fiber_set_joinable(send, true);
  fiber_set_joinable(consume, true);

  fiber_start(receive, channel);
  fiber_start(send, channel);
  fiber_start(consume, channel);

  fiber_join(receive);
  fiber_join(send);
  fiber_join(consume);

  return 0;
}

void transport_channel_free_write_payload(transport_channel_t *channel, transport_payload_t *payload)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  mempool_free(&context->write_buffers, payload->data);
  mempool_free(&context->payloads, payload);
}

void transport_channel_free_read_payload(transport_channel_t *channel, transport_payload_t *payload)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  mempool_free(&context->read_buffers, payload->data);
  mempool_free(&context->payloads, payload);
}

void transport_close_channel(transport_channel_t *channel)
{
  free(channel);
}