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

static inline transport_message_t *transport_controller_create_message(transport_controller_t *controller, Dart_Port port, void *payload, transport_payload_type_t type)
{
  transport_message_t *message = malloc(sizeof(transport_message_t));
  message->port = port;
  message->payload = payload;
  message->payload_type = type;
  return message;
}

static inline transport_data_payload_t *transport_channel_allocate_data_payload(transport_channel_t *channel)
{
  return (transport_data_payload_t *)mempool_alloc(&channel->data_payload_pool);
}

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
  channel->fd = fd;
  channel->controller = controller;
  channel->transport = transport;

  mempool_create(&channel->data_payload_pool, &transport->cache, sizeof(transport_data_payload_t));
  mempool_create(&channel->accept_payload_pool, &transport->cache, sizeof(transport_accept_payload_t));

  ibuf_create(&channel->read_buffers[0], &transport->cache, configuration->buffer_initial_capacity);
  ibuf_create(&channel->read_buffers[1], &transport->cache, configuration->buffer_initial_capacity);
  channel->current_read_buffer = &channel->read_buffers[0];

  ibuf_create(&channel->write_buffers[0], &transport->cache, configuration->buffer_initial_capacity);
  ibuf_create(&channel->write_buffers[1], &transport->cache, configuration->buffer_initial_capacity);
  channel->current_write_buffer = &channel->write_buffers[0];

  channel->payload_buffer_size = configuration->payload_buffer_size;
  channel->buffer_initial_capacity = configuration->buffer_initial_capacity;
  channel->buffer_limit = configuration->buffer_limit;
  channel->current_read_size = 0;
  channel->current_write_size = 0;

  channel->read_port = read_port;
  channel->write_port = write_port;

  return channel;
}

void transport_close_channel(transport_channel_t *channel)
{
  ibuf_destroy(&channel->read_buffers[0]);
  ibuf_destroy(&channel->read_buffers[1]);

  ibuf_destroy(&channel->write_buffers[0]);
  ibuf_destroy(&channel->write_buffers[1]);

  channel->current_read_size = 0;
  channel->current_write_size = 0;

  mempool_destroy(&channel->data_payload_pool);
  mempool_destroy(&channel->accept_payload_pool);

  close(channel->fd);

  smfree(&channel->transport->allocator, channel, sizeof(transport_channel_t));
}

int32_t transport_channel_queue_read(transport_channel_t *channel, uint64_t offset)
{
  transport_data_payload_t *payload = mempool_alloc(&channel->data_payload_pool);
  if (unlikely(!payload))
  {
    return -1;
  }

  payload->buffer = channel->current_read_buffer;
  payload->size = channel->payload_buffer_size;
  payload->fd = channel->fd;
  payload->offset = offset;
  payload->position = channel->current_read_buffer->wpos;
  payload->buffer_size = channel->payload_buffer_size;
  payload->type = TRANSPORT_PAYLOAD_READ;

  // log_info("queue read message");
  transport_message_t *message = transport_controller_create_message(channel->controller, channel->read_port, payload, TRANSPORT_PAYLOAD_READ);
  transport_controller_send(channel->controller, message);

  channel->current_read_buffer->wpos += channel->payload_buffer_size;
  return 0;
}

int32_t transport_channel_queue_write(transport_channel_t *channel, uint32_t payload_size, uint64_t offset)
{
  transport_data_payload_t *payload = mempool_alloc(&channel->data_payload_pool);
  if (unlikely(!payload))
  {
    return -1;
  }
  payload->buffer = channel->current_write_buffer;
  payload->size = payload_size;
  payload->buffer_size = channel->payload_buffer_size;
  payload->fd = channel->fd;
  payload->offset = offset;
  payload->position = channel->current_write_buffer->wpos;
  payload->type = TRANSPORT_PAYLOAD_WRITE;

  // log_info("queue write message");
  transport_message_t *message = transport_controller_create_message(channel->controller, channel->write_port, payload, TRANSPORT_PAYLOAD_WRITE);
  transport_controller_send(channel->controller, message);

  channel->current_write_buffer->wpos += channel->payload_buffer_size;
  return 0;
}

static int setup_buffer_pool(struct ctx *ctx)
{
	int ret, i;
	void *mapped;
	struct io_uring_buf_reg reg = { .ring_addr = 0,
					.ring_entries = BUFFERS,
					.bgid = 0 };

	ctx->buf_ring_size = (sizeof(struct io_uring_buf) + buffer_size(ctx)) * BUFFERS;
	mapped = mmap(NULL, ctx->buf_ring_size, PROT_READ | PROT_WRITE, MAP_ANONYMOUS | MAP_PRIVATE, 0, 0);
	if (mapped == MAP_FAILED) {
		fprintf(stderr, "buf_ring mmap: %s\n", strerror(errno));
		return -1;
	}
	ctx->buf_ring = (struct io_uring_buf_ring *)mapped;

	io_uring_buf_ring_init(ctx->buf_ring);

	reg = (struct io_uring_buf_reg) {
		.ring_addr = (unsigned long)ctx->buf_ring,
		.ring_entries = BUFFERS,
		.bgid = 0
	};
	ctx->buffer_base = (unsigned char *)ctx->buf_ring + sizeof(struct io_uring_buf) * BUFFERS;

	ret = io_uring_register_buf_ring(&ctx->ring, &reg, 0);
	if (ret) {
		fprintf(stderr, "buf_ring init failed: %s\n" "NB This requires a kernel version >= 6.0\n",  strerror(-ret));
		return ret;
	}

	for (i = 0; i < BUFFERS; i++) {
		io_uring_buf_ring_add(ctx->buf_ring, get_buffer(ctx, i), buffer_size(ctx), i, io_uring_buf_ring_mask(BUFFERS), i);
	}
	io_uring_buf_ring_advance(ctx->buf_ring, BUFFERS);

	return 0;
}

void *transport_channel_prepare_read(transport_channel_t *channel)
{  
  struct ibuf *old_buffer = channel->current_read_buffer;
  if (ibuf_unused(old_buffer) >= channel->payload_buffer_size)
  {
    if (ibuf_used(old_buffer) == 0)
      ibuf_reset(old_buffer);
    // log_info("reuse read buffer, current_read_size=%d", channel->current_read_size);
    return old_buffer->wpos;
  }

  if (ibuf_used(old_buffer) == channel->current_read_size)
  {
    // log_info("reserve read buffer, current_read_size=%d", channel->current_read_size);
    ibuf_reserve(old_buffer, channel->payload_buffer_size);
    return old_buffer->wpos;
  }

  struct ibuf *new_buffer = &channel->read_buffers[channel->current_read_buffer == channel->read_buffers];
  if (ibuf_used(new_buffer) != 0)
  {
    log_warn("read buffer is full, current_read_size=%d", channel->current_read_size);
    return NULL;
  }

  // log_info("rotate read buffer, current_read_size=%d", channel->current_read_size);
  ibuf_reserve(new_buffer, channel->payload_buffer_size + channel->current_read_size);

  old_buffer->wpos -= channel->current_read_size;
  if (channel->current_read_size != 0)
  {
    memcpy(new_buffer->rpos, old_buffer->wpos, channel->current_read_size);
    new_buffer->wpos += channel->current_read_size;
    if (ibuf_used(old_buffer) == 0)
    {
      if (ibuf_capacity(old_buffer) < channel->buffer_limit)
      {
        ibuf_reset(old_buffer);
      }
      else
      {
        ibuf_destroy(old_buffer);
        ibuf_create(old_buffer, &channel->transport->cache, channel->buffer_initial_capacity);
      }
    }
  }

  channel->current_read_buffer = new_buffer;
  return new_buffer->wpos;
}

void *transport_channel_prepare_write(transport_channel_t *channel)
{
  struct ibuf *old_buffer = channel->current_write_buffer;
  if (ibuf_unused(old_buffer) >= channel->payload_buffer_size)
  {
    if (ibuf_used(old_buffer) == 0)
      ibuf_reset(old_buffer);
    // log_info("reuse write buffer, current_write_size=%d", channel->current_write_size);
    return old_buffer->wpos;
  }

  if (ibuf_used(old_buffer) == channel->current_write_size)
  {
    ibuf_reserve(old_buffer, channel->payload_buffer_size);
    // log_info("reserve write buffer, current_write_size=%d", channel->current_write_size);
    return old_buffer->wpos;
  }

  struct ibuf *new_buffer = &channel->write_buffers[channel->current_write_buffer == channel->write_buffers];
  if (ibuf_used(new_buffer) != 0)
  {
    log_warn("write buffer is full, current_write_size=%d", channel->current_write_size);
    return NULL;
  }

  // log_info("rotate write buffer, current_write_size=%d", channel->current_write_size);
  ibuf_reserve(new_buffer, channel->payload_buffer_size + channel->current_write_size);

  old_buffer->wpos -= channel->current_write_size;
  if (channel->current_write_size != 0)
  {
    memcpy(new_buffer->rpos, old_buffer->wpos, channel->current_write_size);
    new_buffer->wpos += channel->current_write_size;
    if (ibuf_used(old_buffer) == 0)
    {
      if (ibuf_capacity(old_buffer) < channel->buffer_limit)
      {
        ibuf_reset(old_buffer);
      }
      else
      {
        ibuf_destroy(old_buffer);
        ibuf_create(old_buffer, &channel->transport->cache, channel->buffer_initial_capacity);
      }
    }
  }

  channel->current_write_buffer = new_buffer;
  return new_buffer->wpos;
}

void *transport_channel_extract_read_buffer(transport_channel_t *channel, transport_data_payload_t *message)
{
  void *buffer = message->buffer->rpos + channel->current_read_size;
  // log_info("before extract read buffer, current_read_size=%d", channel->current_read_size);
  channel->current_read_size += channel->payload_buffer_size;
  // log_info("after extract read buffer, current_read_size=%d", channel->current_read_size);
  return buffer;
}

void *transport_channel_extract_write_buffer(transport_channel_t *channel, transport_data_payload_t *message)
{
  void *buffer = message->buffer->rpos + channel->current_write_size;
  // log_info("before extract write buffer, current_write_size=%d", channel->current_write_size);
  channel->current_write_size += channel->payload_buffer_size;
  // log_info("after extract write buffer, current_write_size=%d", channel->current_write_size);
  return buffer;
}

void transport_channel_free_data_payload(transport_channel_t *channel, transport_data_payload_t *payload)
{
  payload->buffer->rpos += channel->payload_buffer_size;
  if (payload->type == TRANSPORT_PAYLOAD_READ)
  {
    // log_info("before free data read payload, current_read_size=%d", channel->current_read_size);
    channel->current_read_size -= channel->payload_buffer_size;
    // log_info("after free data read payload, current_read_size=%d", channel->current_read_size);
  }
  if (payload->type == TRANSPORT_PAYLOAD_WRITE)
  {
    // log_info("before free data write payload, current_write_size=%d", channel->current_write_size);
    channel->current_write_size -= channel->payload_buffer_size;
    // log_info("after free data write payload, current_write_size=%d", channel->current_write_size);
  }
  mempool_free(&channel->data_payload_pool, payload);
}
