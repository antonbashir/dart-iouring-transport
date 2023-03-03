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

static volatile uint32_t next_id = 0;

struct transport_channel_context
{
  struct io_uring *ring;

  uint32_t id;

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
  channel->id = ++next_id;

  context->buffer_size = 1U << configuration->buffer_shift;
  mempool_create(&context->write_buffers, &channel->transport->cache, context->buffer_size);
  mempool_create(&context->read_buffers, &channel->transport->cache, context->buffer_size);
  mempool_create(&context->payloads, &channel->transport->cache, sizeof(transport_payload_t));

  log_info("channel initialized");
  return channel;
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

void transport_channel_handle_accept(struct transport_channel *channel, int fd)
{
  log_debug("channel handle accept %d", fd);
  dart_post_int(fd, channel->accept_port);
}

void transport_channel_handle_write(struct transport_channel *channel, struct io_uring_cqe *cqe)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  log_debug("channel handle write cqe res = %d", cqe->res);
  transport_payload_t *payload = (transport_payload_t *)(cqe->user_data & ~TRANSPORT_PAYLOAD_ALL_FLAGS);
  payload->size = cqe->res;
  log_debug("channel send write data to dart, data size = %d", payload->size);
  dart_post_pointer(payload, channel->write_port);
}

void transport_channel_handle_read(struct transport_channel *channel, struct io_uring_cqe *cqe)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  log_debug("channel read accept cqe res = %d", cqe->res);
  transport_payload_t *payload = (transport_payload_t *)(cqe->user_data & ~TRANSPORT_PAYLOAD_ALL_FLAGS);
  payload->size = cqe->res;
  log_debug("channel send read data to dart, data size = %d", payload->size);
  dart_post_pointer(payload, channel->read_port);
}

int transport_channel_write(struct transport_channel *channel, transport_payload_t *payload)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  struct io_uring_sqe *sqe = provide_sqe(context->ring);
  io_uring_prep_send_zc(sqe, payload->fd, payload->data, payload->size, 0, 0);
  io_uring_sqe_set_data64(sqe, (uint64_t)((intptr_t)payload | TRANSPORT_PAYLOAD_WRITE));
  log_debug("channel send data to ring, data size = %d", payload->size);
  return io_uring_submit(context->ring);
}

int transport_channel_read(struct transport_channel *channel, int fd)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  transport_payload_t *payload = mempool_alloc(&context->payloads);
  payload->fd = fd;
  payload->size = context->buffer_size;
  payload->data = mempool_alloc(&context->read_buffers);
  struct io_uring_sqe *sqe = provide_sqe(context->ring);
  io_uring_prep_read(sqe, payload->fd, payload->data, payload->size, 0);
  io_uring_sqe_set_data64(sqe, (uint64_t)((intptr_t)payload | TRANSPORT_PAYLOAD_READ));
  log_debug("channel receive data with ring, data size = %d", payload->size);
  return io_uring_submit(context->ring);
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

void transport_channel_register(struct transport_channel *channel, struct io_uring *ring)
{
  struct transport_channel_context *context = (struct transport_channel_context *)channel->context;
  context->ring = ring;
}