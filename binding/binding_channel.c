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

transport_channel_t *transport_initialize_channel(transport_t *transport,
                                                  transport_listener_t *listener,
                                                  transport_channel_configuration_t *configuration,
                                                  Dart_Port accept_port,
                                                  Dart_Port connect_port,
                                                  Dart_Port read_port,
                                                  Dart_Port write_port)
{
  transport_channel_t *channel = smalloc(&transport->allocator, sizeof(transport_channel_t));
  if (!channel)
  {
    return NULL;
  }
  channel->fd = -1;
  channel->listener = listener;
  channel->transport = transport;

  mempool_create(&channel->data_payload_pool, &transport->cache, sizeof(transport_data_payload_t));
  mempool_create(&channel->accept_payload_pool, &transport->cache, sizeof(transport_accept_payload_t));

  ibuf_create(&channel->read_buffers[0], &transport->cache, configuration->buffer_initial_capacity);
  ibuf_create(&channel->read_buffers[1], &transport->cache, configuration->buffer_initial_capacity);
  channel->current_read_buffer = &channel->read_buffers[0];

  ibuf_create(&channel->write_buffers[0], &transport->cache, configuration->buffer_initial_capacity);
  ibuf_create(&channel->write_buffers[1], &transport->cache, configuration->buffer_initial_capacity);
  channel->current_write_buffer = &channel->write_buffers[0];

  channel->buffer_initial_capacity = configuration->buffer_initial_capacity;
  channel->buffer_limit = configuration->buffer_limit;
  channel->current_read_size = 0;
  channel->current_write_size = 0;

  channel->accept_port = accept_port;
  channel->connect_port = connect_port;
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

  if (channel->fd != -1)
    close(channel->fd);

  smfree(&channel->transport->allocator, channel, sizeof(transport_channel_t));
}

int32_t transport_channel_queue_read(transport_channel_t *channel, uint64_t offset)
{
  if (io_uring_sq_space_left(&channel->transport->ring) <= 1)
  {
    return -1;
  }

  struct io_uring_sqe *sqe = io_uring_get_sqe(&channel->transport->ring);
  if (sqe == NULL)
  {
    return -1;
  }

  transport_data_payload_t *payload = mempool_alloc(&channel->data_payload_pool);
  if (!payload)
  {
    return -1;
  }

  payload->buffer = channel->current_read_buffer;
  payload->size = channel->payload_buffer_size;
  payload->fd = channel->fd;
  payload->type = TRANSPORT_PAYLOAD_READ;

  io_uring_prep_read(sqe, channel->fd, channel->current_read_buffer->wpos, channel->payload_buffer_size, offset);
  io_uring_sqe_set_data(sqe, transport_listener_create_message(channel->listener, channel->read_port, payload));

  channel->current_read_buffer->wpos += channel->payload_buffer_size;
  return 0;
}

int32_t transport_channel_queue_write(transport_channel_t *channel, uint32_t payload_size, uint64_t offset)
{
  if (io_uring_sq_space_left(&channel->transport->ring) <= 1)
  {
    return -1;
  }

  struct io_uring_sqe *sqe = io_uring_get_sqe(&channel->transport->ring);
  if (sqe == NULL)
  {
    return -1;
  }

  transport_data_payload_t *payload = mempool_alloc(&channel->data_payload_pool);
  if (!payload)
  {
    return -1;
  }
  payload->buffer = channel->current_write_buffer;
  payload->size = channel->payload_buffer_size;
  payload->fd = channel->fd;
  payload->type = TRANSPORT_PAYLOAD_WRITE;

  io_uring_prep_write(sqe, channel->fd, channel->current_write_buffer->wpos, payload_size, offset);
  io_uring_sqe_set_data(sqe, transport_listener_create_message(channel->listener, channel->write_port, payload));

  channel->current_write_buffer->wpos += channel->payload_buffer_size;
  return 0;
}

int32_t transport_channel_queue_accept(transport_channel_t *channel, int32_t server_socket_fd)
{
  struct io_uring_sqe *sqe = io_uring_get_sqe(&channel->transport->ring);
  if (sqe == NULL)
  {
    return -1;
  }

  transport_accept_payload_t *payload = mempool_alloc(&channel->accept_payload_pool);
  if (!payload)
  {
    return -1;
  }
  memset(&payload->client_addres, 0, sizeof(payload->client_addres));
  payload->client_addres_length = sizeof(payload->client_addres);
  payload->fd = server_socket_fd;
  payload->type = TRANSPORT_PAYLOAD_ACCEPT;

  io_uring_prep_accept(sqe, server_socket_fd, (struct sockaddr *)&payload->client_addres, &payload->client_addres_length, 0);
  io_uring_sqe_set_data(sqe, transport_listener_create_message(channel->listener, channel->accept_port, payload));
}

int32_t transport_channel_queue_connect(transport_channel_t *channel, int32_t socket_fd, const char *ip, int32_t port)
{
  struct io_uring_sqe *sqe = io_uring_get_sqe(&channel->transport->ring);
  if (sqe == NULL)
  {
    return -1;
  }

  transport_accept_payload_t *payload = mempool_alloc(&channel->accept_payload_pool);
  if (!payload)
  {
    return -1;
  }
  memset(&payload->client_addres, 0, sizeof(payload->client_addres));
  payload->client_addres.sin_addr.s_addr = inet_addr(ip);
  payload->client_addres.sin_port = htons(port);
  payload->client_addres.sin_family = AF_INET;
  payload->client_addres_length = sizeof(payload->client_addres);
  payload->fd = socket_fd;
  payload->type = TRANSPORT_PAYLOAD_CONNECT;

  io_uring_prep_connect(sqe, socket_fd, (struct sockaddr *)&payload->client_addres, payload->client_addres_length);
  io_uring_sqe_set_data(sqe, transport_listener_create_message(channel->listener, channel->connect_port, payload));
}

void *transport_channel_prepare_read(transport_channel_t *channel, size_t size)
{
  struct ibuf *old_buffer = channel->current_read_buffer;
  if (ibuf_unused(old_buffer) >= size)
  {
    if (ibuf_used(old_buffer) == 0)
      ibuf_reset(old_buffer);
    return old_buffer->wpos;
  }

  if (ibuf_used(old_buffer) == channel->current_read_size)
  {
    ibuf_reserve(old_buffer, size);
    return old_buffer->wpos;
  }

  struct ibuf *new_buffer = &channel->read_buffers[channel->current_read_buffer == channel->read_buffers];
  if (ibuf_used(new_buffer) != 0)
  {
    return NULL;
  }

  ibuf_reserve(new_buffer, size + channel->current_read_size);

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

void *transport_channel_prepare_write(transport_channel_t *channel, size_t size)
{
  struct ibuf *old_buffer = channel->current_write_buffer;
  if (ibuf_unused(old_buffer) >= size)
  {
    if (ibuf_used(old_buffer) == 0)
      ibuf_reset(old_buffer);
    return old_buffer->wpos;
  }

  if (ibuf_used(old_buffer) == channel->current_write_size)
  {
    ibuf_reserve(old_buffer, size);
    return old_buffer->wpos;
  }

  struct ibuf *new_buffer = &channel->write_buffers[channel->current_write_buffer == channel->write_buffers];
  if (ibuf_used(new_buffer) != 0)
  {
    return NULL;
  }

  ibuf_reserve(new_buffer, size + channel->current_write_size);

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
  channel->current_read_size += message->size;
  return buffer;
}

void *transport_channel_extract_write_buffer(transport_channel_t *channel, transport_data_payload_t *message)
{
  void *buffer = message->buffer->rpos + channel->current_write_size;
  channel->current_write_size += message->size;
  return buffer;
}

transport_accept_payload_t *transport_channel_allocate_accept_payload(transport_channel_t *channel)
{
  return (transport_accept_payload_t *)mempool_alloc(&channel->accept_payload_pool);
}

transport_data_payload_t *transport_channel_allocate_data_payload(transport_channel_t *channel)
{
  return (transport_data_payload_t *)mempool_alloc(&channel->data_payload_pool);
}

void transport_channel_free_data_payload(transport_channel_t *channel, transport_data_payload_t *payload)
{
  payload->buffer->rpos += payload->size;
  if (payload->type == TRANSPORT_PAYLOAD_READ)
  {
    channel->current_read_size -= payload->size;
  }
  if (payload->type == TRANSPORT_PAYLOAD_WRITE)
  {
    channel->current_write_size -= payload->size;
  }
  mempool_free(&channel->data_payload_pool, payload);
}

void transport_channel_free_accept_payload(transport_channel_t *channel, transport_accept_payload_t *payload)
{
  mempool_free(&channel->accept_payload_pool, payload);
}
