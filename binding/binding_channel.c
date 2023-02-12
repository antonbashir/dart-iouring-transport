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
#include "fiber_channel.h"
#include "fiber.h"

transport_channel_t *transport_initialize_channel(transport_t *transport,
                                                  transport_controller_t *controller,
                                                  transport_channel_configuration_t *configuration,
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

  channel->payload_buffer_size = configuration->payload_buffer_size;
  channel->buffer_initial_capacity = configuration->buffer_initial_capacity;
  channel->buffer_limit = configuration->buffer_limit;

  channel->read_port = read_port;
  channel->write_port = write_port;

  size_t buffer_ring_size = (sizeof(struct io_uring_buf) + configuration->payload_buffer_size) * configuration->buffers_count;
  void *mapped = mmap(NULL, buffer_ring_size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, 0, 0);
  if (mapped == MAP_FAILED)
  {
    return -1;
  }
  struct io_uring_buf_ring *buffer_ring = (struct io_uring_buf_ring *)mapped;

  io_uring_buf_ring_init(buffer_ring);

  struct io_uring_buf_reg reg = {
      .ring_addr = (unsigned long)buffer_ring,
      .ring_entries = configuration->buffers_count,
      .bgid = 0,
  };
  unsigned char *buffer_base = (unsigned char *)buffer_ring + sizeof(struct io_uring_buf) * configuration->buffers_count;

  if (!io_uring_register_buf_ring(&ctx->ring, &reg, 0))
  {
    return NULL;
  }

  int ret, buffer_index;
  for (buffer_index = 0; buffer_index < configuration->buffers_count; buffer_index++)
  {
    io_uring_buf_ring_add(ctx->buf_ring, get_buffer(ctx, buffer_index), configuration->payload_buffer_size, buffer_index, io_uring_buf_ring_mask(configuration->buffers_count), buffer_index);
  }

  io_uring_buf_ring_advance(ctx->buf_ring, configuration->buffers_count);

  return channel;
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

void *transport_channel_extract_read_buffer(transport_channel_t *channel, transport_data_payload_t *message)
{
}

void *transport_channel_extract_write_buffer(transport_channel_t *channel, transport_data_payload_t *message)
{
}

int transport_channel_loop(va_list input)
{
  struct transport_acceptor *acceptor = va_arg(input, struct transport_acceptor *);
  struct transport_acceptor_context *context = (struct transport_acceptor_context *)acceptor->context;
  while (acceptor->active)
  {
    if (!fiber_channel_is_empty(context->channel))
    {
      struct transport_message *message;
      if (likely(fiber_channel_get(context->channel, &message)))
      {
        int fd = (int)message->data;
        free(message);
        struct io_uring_sqe *sqe = io_uring_get_sqe(&context->ring);
        while (unlikely(sqe == NULL))
        {
          fiber_sleep(0);
        }
        io_uring_prep_multishot_accept(sqe, fd, (struct sockaddr *)&context->client_addres, &context->client_addres_length, 0);
        io_uring_sqe_set_data(sqe, fd);
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
      int fd = cqe->res;
      struct io_uring_sqe *sqe = io_uring_get_sqe(&context->ring);
      while (unlikely(sqe == NULL))
      {
        fiber_sleep(0);
      }
      struct transport_channel *channel = context->balancer->next();
      io_uring_prep_msg_ring(sqe, channel->ring.ring_fd, sizeof(fd), fd, 0);
      io_uring_sqe_set_data(sqe, 1);
      io_uring_submit(&context->ring);
    }
    io_uring_cq_advance(&context->ring, count);
    transport_acceptor_accept(acceptor);
    fiber_sleep(0);
  }
  return 0;
}