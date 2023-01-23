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

  mempool_create(&context->data_message_pool, &context->cache, sizeof(transport_data_message_t));
  mempool_create(&context->accept_message_pool, &context->cache, sizeof(transport_accept_message_t));
  mempool_create(&context->cqe_pool, &context->cache, sizeof(struct io_uring_cqe));
  mempool_create(&context->payload_pool, &context->cache, sizeof(transport_payload_t));

  ibuf_create(&context->read_buffers[0], &context->cache, configuration->buffer_initial_capacity);
  ibuf_create(&context->read_buffers[1], &context->cache, configuration->buffer_initial_capacity);
  context->current_read_buffer = &context->read_buffers[0];

  ibuf_create(&context->write_buffers[0], &context->cache, configuration->buffer_initial_capacity);
  ibuf_create(&context->write_buffers[1], &context->cache, configuration->buffer_initial_capacity);
  context->current_write_buffer = &context->write_buffers[0];

  context->buffer_initial_capacity = configuration->buffer_initial_capacity;
  context->buffer_limit = configuration->buffer_limit;
  context->current_read_size = 0;
  context->current_write_size = 0;

  return context;
}

void transport_close(transport_context_t *context)
{
  io_uring_queue_exit(&context->ring);

  ibuf_destroy(&context->read_buffers[0]);
  ibuf_destroy(&context->read_buffers[1]);
  context->current_read_buffer = NULL;

  ibuf_destroy(&context->write_buffers[0]);
  ibuf_destroy(&context->write_buffers[1]);
  context->current_write_buffer = NULL;

  small_alloc_destroy(&context->allocator);
  slab_cache_destroy(&context->cache);
  slab_arena_destroy(&context->arena);

  free(context);
}

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
  if (type == TRANSPORT_MESSAGE_READ || type == TRANSPORT_MESSAGE_WRITE)
  {
    mempool_free(&context->data_message_pool, (void *)cqe->user_data);
    io_uring_cqe_seen(&context->ring, cqe);
    return;
  }
  mempool_free(&context->accept_message_pool, (void *)cqe->user_data);
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

  transport_data_message_t *message = mempool_alloc(&context->data_message_pool);
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

  transport_data_message_t *message = mempool_alloc(&context->data_message_pool);
  if (!message)
  {
    return -1;
  }
  message->write_buffer = context->current_write_buffer;
  message->size = size;
  message->fd = fd;
  message->type = TRANSPORT_MESSAGE_WRITE;

  io_uring_prep_write(sqe, fd, context->current_write_buffer->wpos, ibuf_unused(context->current_write_buffer), offset);
  io_uring_sqe_set_data(sqe, message);

  context->current_write_size += message->size;
  context->current_write_buffer->wpos += message->size;

  return 0;
}

int32_t transport_queue_accept(transport_context_t *context, int32_t server_socket_fd)
{
  struct io_uring_sqe *sqe = io_uring_get_sqe(&context->ring);
  if (sqe == NULL)
  {
    return -1;
  }

  transport_accept_message_t *request = mempool_alloc(&context->accept_message_pool);
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

  transport_accept_message_t *request = mempool_alloc(&context->accept_message_pool);
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

void transport_close_descriptor(int32_t fd)
{
  close(fd);
}

void *transport_prepare_read(transport_context_t *context, size_t size)
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

  struct ibuf *new_buffer = &context->read_buffers[context->current_read_buffer == context->read_buffers];
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

void *transport_prepare_write(transport_context_t *context, size_t size)
{
  struct ibuf *old_buffer = context->current_write_buffer;
  if (ibuf_unused(old_buffer) >= size)
  {
    if (ibuf_used(old_buffer) == 0)
      ibuf_reset(old_buffer);
    return old_buffer->wpos;
  }

  if (ibuf_used(old_buffer) == context->current_write_size)
  {
    ibuf_reserve(old_buffer, size);
    return old_buffer->wpos;
  }

  struct ibuf *new_buffer = &context->write_buffers[context->current_write_buffer == context->write_buffers];
  if (ibuf_used(new_buffer) != 0)
  {
    return NULL;
  }

  ibuf_reserve(new_buffer, size + context->current_write_size);

  old_buffer->wpos -= context->current_write_size;
  if (context->current_write_size != 0)
  {
    memcpy(new_buffer->rpos, old_buffer->wpos, context->current_write_size);
    new_buffer->wpos += context->current_write_size;
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

  context->current_write_buffer = new_buffer;
  return new_buffer->wpos;
}

struct io_uring_cqe **transport_allocate_cqes(transport_context_t *context, uint32_t count)
{
  return smalloc(&context->allocator, sizeof(struct io_uring_cqe *) * count);
}

void transport_free_cqes(transport_context_t *context, struct io_uring_cqe **cqes, uint32_t count)
{
  smfree(&context->allocator, cqes, sizeof(struct io_uring_cqe *) * count);
}

void *transport_extract_read_buffer(transport_context_t *context, transport_data_message_t *message)
{
  return message->read_buffer->rpos;
}

void *transport_extract_write_buffer(transport_context_t *context, transport_data_message_t *message)
{
  return message->write_buffer->rpos;
}

size_t transport_read_buffer_used(transport_context_t *context)
{
  return ibuf_used(context->current_read_buffer);
}

size_t transport_write_buffer_used(transport_context_t *context)
{
  return ibuf_used(context->current_write_buffer);
}

void *transport_allocate_object(transport_context_t *context, size_t size)
{
  return smalloc(&context->allocator, size);
}

void transport_free_object(transport_context_t *context, void *object, size_t size)
{
  smfree(&context->allocator, object, size);
}

transport_payload_t *transport_create_payload(transport_context_t *context, void *buffer, transport_data_message_t *message)
{
  transport_payload_t *data = mempool_alloc(&context->payload_pool);
  data->context = context;
  data->buffer = buffer;
  data->message = message;
  return data;
}

static inline void transport_finalize_read(transport_context_t *context, transport_data_message_t *message)
{
  message->read_buffer->rpos += message->size;
  message->size = 0;
  context->current_read_size -= message->size;
}

static inline void transport_finalize_write(transport_context_t *context, transport_data_message_t *message)
{
  message->write_buffer->rpos += message->size;
  message->size = 0;
  context->current_write_size -= message->size;
}

void transport_finalize_payload(transport_payload_t *data)
{
  if (data->message->type == TRANSPORT_MESSAGE_READ)
  {
    transport_finalize_read(data->context, data->message);
  }
  if (data->message->type == TRANSPORT_MESSAGE_WRITE)
  {
    transport_finalize_write(data->context, data->message);
  }
  transport_free_object(data->context, data, sizeof(transport_payload_t));
}
