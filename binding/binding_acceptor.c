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
#include "binding_acceptor.h"
#include "binding_common.h"
#include "binding_message.h"
#include "binding_channel.h"
#include "binding_balancer.h"
#include "binding_socket.h"
#include "fiber.h"

struct transport_acceptor_context
{
  struct io_uring ring;
  struct fiber_channel *channel;
  struct transport_balancer *balancer;
  struct sockaddr_in client_addres;
  socklen_t client_addres_length;
  int fd;
};

static inline void dart_post_pointer(void *pointer, Dart_Port port)
{
  Dart_CObject dart_object;
  dart_object.type = Dart_CObject_kInt64;
  dart_object.value.as_int64 = (int64_t)pointer;
  Dart_PostCObject(port, &dart_object);
};

int transport_acceptor_loop(va_list input)
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
          io_uring_submit(&context->ring);
          fiber_sleep(0);
          sqe = io_uring_get_sqe(&context->ring);
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
      io_uring_prep_msg_ring(sqe, channel->ring.ring_fd, fd, TRANSPORT_PAYLOAD_ACCEPT, 0);
      io_uring_submit(&context->ring);
    }
    io_uring_cq_advance(&context->ring, count);
    if (count)
    {
      transport_acceptor_accept(acceptor);
    }
    fiber_sleep(0);
  }
  return 0;
}

transport_acceptor_t *transport_initialize_acceptor(transport_t *transport,
                                                    transport_controller_t *controller,
                                                    transport_acceptor_configuration_t *configuration,
                                                    const char *ip,
                                                    int32_t port,
                                                    Dart_Port dart_port)
{
  transport_acceptor_t *acceptor = smalloc(&transport->allocator, sizeof(transport_acceptor_t));
  if (!acceptor)
  {
    return NULL;
  }
  acceptor->controller = controller;
  acceptor->transport = transport;
  acceptor->dart_port = dart_port;

  struct transport_acceptor_context *context = smalloc(&transport->allocator, sizeof(struct transport_acceptor_context));

  memset(&context->client_addres, 0, sizeof(context->client_addres));
  context->client_addres.sin_addr.s_addr = inet_addr(acceptor->client_ip);
  context->client_addres.sin_port = htons(acceptor->client_port);
  context->client_addres.sin_family = AF_INET;
  context->client_addres_length = sizeof(context->client_addres);
  context->fd = transport_socket_create();
  if (!transport_socket_bind(context->fd, ip, port, configuration->backlog))
  {
    return NULL;
  }

  acceptor->context = context;

  int32_t status = io_uring_queue_init(configuration->ring_size, &context->ring, IORING_SETUP_SUBMIT_ALL | IORING_SETUP_COOP_TASKRUN | IORING_SETUP_CQSIZE);
  if (status)
  {
    log_error("io_urig init error: %d", status);
    free(&context->ring);
    smfree(&transport->allocator, context, sizeof(struct transport_acceptor_context));
    return NULL;
  }

  context->channel = fiber_channel_new(configuration->ring_size);

  return acceptor;
}

void transport_close_acceptor(transport_acceptor_t *acceptor)
{
  struct transport_acceptor_context *context = (struct transport_acceptor_context *)acceptor->context;
  io_uring_queue_exit(&context->ring);
  smfree(&acceptor->transport->allocator, acceptor, sizeof(transport_acceptor_t));
}

int32_t transport_acceptor_accept(transport_acceptor_t *acceptor)
{
  struct transport_acceptor_context *context = (struct transport_acceptor_context *)acceptor->context;
  struct transport_message *message = malloc(sizeof(struct transport_message *));
  message->channel = context->channel;
  message->data = context->fd;
  return transport_controller_send(acceptor->controller, message) ? 0 : -1;
}