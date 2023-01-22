#include "binding_transport.h"
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

int32_t transport_submit_receive(transport_context_t *context, struct io_uring_cqe **cqes, uint32_t cqes_size, bool wait)
{
  int32_t submit_result = io_uring_submit(&context->ring);
  if (submit_result < 0)
  {
    if (submit_result != -EBUSY)
    {
      return -1;
    }
  }

  submit_result = io_uring_peek_batch_cqe(&context->ring, cqes, cqes_size);
  if (submit_result == 0 && wait)
  {
    submit_result = io_uring_wait_cqe(&context->ring, cqes);
    if (submit_result < 0)
    {
      return -1;
    }
    submit_result = 0;
  }

  return (int32_t)submit_result;
}

void transport_mark_cqe(transport_context_t *context, transport_message_type_t type, struct io_uring_cqe *cqe)
{
  smfree(&context->allocator, (void *)cqe->user_data, type == TRANSPORT_MESSAGE_READ || type == TRANSPORT_MESSAGE_WRITE ? sizeof(transport_message_t) : sizeof(transport_accept_request_t));
  io_uring_cqe_seen(&context->ring, cqe);
}

int32_t transport_queue_read(transport_context_t *context, int32_t fd, uint32_t size, uint64_t offset)
{
  if (io_uring_sq_space_left(&context->ring) <= 1)
  {
    return -1;
  }

  struct io_uring_sqe *sqe = io_uring_get_sqe(&context->ring);
  if (sqe == NULL)
  {
    return -1;
  }

  transport_message_t *message = smalloc(&context->allocator, sizeof(transport_message_t));
  if (!message)
  {
    return -1;
  }

  message->read_buffer = context->current_read_buffer;
  message->size = size;
  message->fd = fd;
  message->type = TRANSPORT_MESSAGE_READ;

  io_uring_prep_read(sqe, fd, context->current_read_buffer->wpos, ibuf_unused(context->current_read_buffer), offset);
  io_uring_sqe_set_data(sqe, message);

  context->current_read_size += message->size;
  context->current_read_buffer->wpos += message->size;

  return 0;
}

int32_t transport_queue_write(transport_context_t *context, int32_t fd, void *buffer, uint32_t size, uint64_t offset)
{
  if (io_uring_sq_space_left(&context->ring) <= 1)
  {
    return -1;
  }

  struct io_uring_sqe *sqe = io_uring_get_sqe(&context->ring);
  if (sqe == NULL)
  {
    return -1;
  }

  transport_message_t *message = smalloc(&context->allocator, sizeof(transport_message_t));
  if (!message)
  {
    return -1;
  }
  message->write_buffer = context->current_write_buffer;
  message->size = size;
  message->fd = fd;
  message->type = TRANSPORT_MESSAGE_WRITE;

  obuf_alloc(context->current_write_buffer, size);
  io_uring_prep_writev(sqe, fd, context->current_write_buffer->iov, obuf_iovcnt(context->current_write_buffer), offset);
  io_uring_sqe_set_data(sqe, message);

  return 0;
}

int32_t transport_queue_accept(transport_context_t *context, int32_t server_socket_fd)
{
  struct io_uring_sqe *sqe = io_uring_get_sqe(&context->ring);
  if (sqe == NULL)
  {
    return -1;
  }

  transport_accept_request_t *request = smalloc(&context->allocator, sizeof(transport_accept_request_t));
  if (!request)
  {
    return -1;
  }
  memset(&request->client_addres, 0, sizeof(request->client_addres));
  request->client_addres_length = sizeof(request->client_addres);
  request->fd = server_socket_fd;
  request->type = TRANSPORT_MESSAGE_ACCEPT;

  io_uring_prep_accept(sqe, server_socket_fd, (struct sockaddr *)&request->client_addres, &request->client_addres_length, 0);
  io_uring_sqe_set_data(sqe, request);
}

int32_t transport_queue_connect(transport_context_t *context, int32_t socket_fd, const char *ip, int32_t port)
{
  struct io_uring_sqe *sqe = io_uring_get_sqe(&context->ring);
  if (sqe == NULL)
  {
    return -1;
  }

  transport_accept_request_t *request = smalloc(&context->allocator, sizeof(transport_accept_request_t));
  if (!request)
  {
    return -1;
  }
  memset(&request->client_addres, 0, sizeof(request->client_addres));
  request->client_addres.sin_addr.s_addr = inet_addr(ip);
  request->client_addres.sin_port = htons(port);
  request->client_addres.sin_family = AF_INET;
  request->client_addres_length = sizeof(request->client_addres);
  request->fd = socket_fd;
  request->type = TRANSPORT_MESSAGE_CONNECT;

  io_uring_prep_connect(sqe, socket_fd, (struct sockaddr *)&request->client_addres, request->client_addres_length);
  io_uring_sqe_set_data(sqe, request);
}

transport_context_t *transport_initialize(transport_configuration_t *configuration)
{
  transport_context_t *context = malloc(sizeof(transport_context_t));
  if (!context)
  {
    return NULL;
  }

  if (io_uring_queue_init(configuration->ring_size, &context->ring, 0) != 0)
  {
    free(&context->ring);
    return NULL;
  }

  quota_init(&context->quota, configuration->memory_quota);
  slab_arena_create(&context->arena, &context->quota, 0, configuration->slab_size, MAP_PRIVATE);
  slab_cache_create(&context->cache, &context->arena);
  float actual_allocation_factor;
  small_alloc_create(&context->allocator,
                     &context->cache,
                     configuration->slab_allocation_minimal_object_size,
                     configuration->slab_allocation_granularity,
                     configuration->slab_allocation_factor,
                     &actual_allocation_factor);

  ibuf_create(&context->read_buffers[0], &context->cache, configuration->buffer_initial_capacity);
  ibuf_create(&context->read_buffers[1], &context->cache, configuration->buffer_initial_capacity);
  context->current_read_buffer = &context->read_buffers[0];

  obuf_create(&context->write_buffers[0], &context->cache, configuration->buffer_initial_capacity);
  obuf_create(&context->write_buffers[1], &context->cache, configuration->buffer_initial_capacity);
  context->current_write_buffer = &context->write_buffers[0];

  region_create(&context->region, &context->cache);

  context->buffer_initial_capacity = configuration->buffer_initial_capacity;
  context->buffer_limit = configuration->buffer_limit;
  context->current_read_size = 0;

  return context;
}

void transport_close(transport_context_t *context)
{
  io_uring_queue_exit(&context->ring);

  ibuf_destroy(&context->read_buffers[0]);
  ibuf_destroy(&context->read_buffers[1]);
  context->current_read_buffer = NULL;

  obuf_destroy(&context->write_buffers[0]);
  obuf_destroy(&context->write_buffers[1]);
  context->current_write_buffer = NULL;

  region_destroy(&context->region);

  small_alloc_destroy(&context->allocator);
  slab_cache_destroy(&context->cache);
  slab_arena_destroy(&context->arena);

  free(context);
}

void transport_close_descriptor(int32_t fd)
{
  close(fd);
}

void *transport_begin_read(transport_context_t *context, size_t size)
{
  struct ibuf *old_buffer = context->current_read_buffer;
  if (ibuf_unused(old_buffer) >= size)
  {
    if (ibuf_used(old_buffer) == 0)
      ibuf_reset(old_buffer);
    return old_buffer->wpos;
  }

  if (ibuf_used(old_buffer) == context->current_read_size)
  {
    ibuf_reserve(old_buffer, size);
    return old_buffer->wpos;
  }

  struct ibuf *new_buffer = &context->read_buffers[context->current_read_buffer == &context->read_buffers[0]];
  if (ibuf_used(new_buffer) != 0)
  {
    return NULL;
  }

  ibuf_reserve(new_buffer, size + context->current_read_size);

  old_buffer->wpos -= context->current_read_size;
  if (context->current_read_size != 0)
  {
    memcpy(new_buffer->rpos, old_buffer->wpos, context->current_read_size);
    new_buffer->wpos += context->current_read_size;
    if (ibuf_used(old_buffer) == 0)
    {
      if (ibuf_capacity(old_buffer) < context->buffer_limit)
      {
        ibuf_reset(old_buffer);
      }
      else
      {
        ibuf_destroy(old_buffer);
        ibuf_create(old_buffer, &context->cache, context->buffer_initial_capacity);
      }
    }
  }

  context->current_read_buffer = new_buffer;
  return new_buffer->wpos;
}

void transport_complete_read(transport_context_t *context, transport_message_t *message)
{
  message->read_buffer->rpos += message->size;
  message->size = 0;
  context->current_read_size -= message->size;
}

void *transport_begin_write(transport_context_t *context, size_t size)
{
  return obuf_reserve(context->current_write_buffer, size);
}

void transport_complete_write(transport_context_t *context, transport_message_t *message)
{
  struct obuf *previos = &context->write_buffers[context->current_write_buffer == context->write_buffers];
  if (message->write_buffer == context->current_write_buffer)
  {
    if (obuf_size(previos) != 0)
      obuf_reset(previos);
  }
  if (obuf_size(context->current_write_buffer) != 0 && obuf_size(previos) == 0)
  {
    context->current_write_buffer = previos;
  }
}

struct io_uring_cqe **transport_allocate_cqes(transport_context_t *context, uint32_t count)
{
  return smalloc(&context->allocator, sizeof(struct io_uring_cqe *) * count);
}

void transport_free_cqes(transport_context_t *context, struct io_uring_cqe **cqes, uint32_t count)
{
  smfree(&context->allocator, cqes, sizeof(struct io_uring_cqe *) * count);
}

void *transport_copy_write_buffer(transport_context_t *context, transport_message_t *message)
{
  size_t result_size = obuf_size(message->write_buffer);
  void *result_buffer = smalloc(&context->allocator, result_size);
  int position = 0;
  int buffer_iov_count = obuf_iovcnt(message->write_buffer);
  for (int iov_index = 0; iov_index < buffer_iov_count; iov_index++)
  {
    memcpy(result_buffer + position, message->write_buffer->iov[iov_index].iov_base, message->write_buffer->iov[iov_index].iov_len);
    position += message->write_buffer->iov[iov_index].iov_len;
  }
  return result_buffer;
}

void *transport_copy_read_buffer(transport_context_t *context, transport_message_t *message)
{
  void *result_buffer = smalloc(&context->allocator, message->size);
  memcpy(message->read_buffer->rpos, result_buffer, message->size);
  return result_buffer;
}

void transport_free_region(transport_context_t *context)
{
  region_free(&context->region);
}

size_t transport_read_buffer_used(transport_context_t *context) 
{
  return ibuf_used(context->current_read_buffer);
}

void* transport_allocate_object(transport_context_t *context, size_t size)
{
  return smalloc(&context->allocator, size);
}

void transport_free_object(transport_context_t *context, void* object, size_t size)
{
  smfree(&context->allocator, object, size);
}