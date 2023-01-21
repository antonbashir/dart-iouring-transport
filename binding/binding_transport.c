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

int32_t transport_submit_receive(struct io_uring *ring, struct io_uring_cqe **cqes, uint32_t cqes_size, bool wait)
{
  int32_t submit_result = io_uring_submit(ring);
  if (submit_result < 0)
  {
    if (submit_result != -EBUSY)
    {
      return -1;
    }
  }

  submit_result = io_uring_peek_batch_cqe(ring, cqes, cqes_size);
  if (submit_result == 0 && wait)
  {
    submit_result = io_uring_wait_cqe(ring, cqes);
    if (submit_result < 0)
    {
      return -1;
    }
    submit_result = 0;
  }

  return (int32_t)submit_result;
}

void transport_mark_cqe(struct io_uring *ring, struct io_uring_cqe *cqe)
{
  free(cqe->user_data);
  io_uring_cqe_seen(ring, cqe);
}

intptr_t transport_queue_read(struct io_uring *ring, int32_t fd, void *buffer, uint32_t buffer_pos, uint32_t buffer_len, uint64_t offset)
{
  if (io_uring_sq_space_left(ring) <= 1)
  {
    return NULL;
  }

  struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
  if (sqe == NULL)
  {
    return NULL;
  }

  transport_message_t *message = malloc(sizeof(*message));
  if (!message)
  {
    return NULL;
  }

  message->buffer = buffer + buffer_pos;
  message->size = buffer_len;
  message->fd = fd;
  message->type = TRANSPORT_MESSAGE_READ;

  io_uring_prep_read(sqe, fd, buffer + buffer_pos, buffer_len, offset);
  io_uring_sqe_set_data(sqe, message);

  return (intptr_t)buffer;
}

intptr_t transport_queue_write(struct io_uring *ring, int32_t fd, void *buffer, uint32_t buffer_pos, uint32_t buffer_len, uint64_t offset)
{
  if (io_uring_sq_space_left(ring) <= 1)
  {
    return NULL;
  }

  struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
  if (sqe == NULL)
  {
    return NULL;
  }

  transport_message_t *message = malloc(sizeof(*message));
  if (!message)
  {
    return NULL;
  }
  message->buffer = buffer + buffer_pos;
  message->size = buffer_len;
  message->fd = fd;
  message->type = TRANSPORT_MESSAGE_WRITE;

  io_uring_prep_write(sqe, fd, buffer + buffer_pos, buffer_len, offset);
  io_uring_sqe_set_data(sqe, message);

  return (intptr_t)buffer;
}

int32_t transport_queue_accept(struct io_uring *ring, int32_t server_socket_fd)
{
  struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
  if (sqe == NULL)
  {
    return -1;
  }

  transport_accept_request_t *request = malloc(sizeof(*request));
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

int32_t transport_queue_connect(struct io_uring *ring, int32_t socket_fd, const char *ip, int32_t port)
{
  struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
  if (sqe == NULL)
  {
    return -1;
  }

  transport_accept_request_t *request = malloc(sizeof(*request));
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

struct io_uring *transport_initialize(transport_configuration_t *configuration)
{
  struct io_uring *ring = malloc(sizeof(struct io_uring));
  if (!ring)
  {
    return -1;
  }

  io_uring_queue_init(configuration->ring_size, ring, 0);
  return ring;
}

void transport_close(struct io_uring *ring)
{
  io_uring_queue_exit(ring);
  free(ring);
  ring = NULL;
}

void transport_close_descriptor(int32_t fd)
{
  close(fd);
}