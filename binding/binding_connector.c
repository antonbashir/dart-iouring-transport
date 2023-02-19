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
#include "binding_connector.h"
#include "binding_common.h"
#include "binding_message.h"
#include "binding_channel.h"
#include "binding_balancer.h"
#include "binding_socket.h"
#include "fiber.h"

struct transport_connector_context
{
  struct io_uring ring;
  struct fiber_channel *channel;
  struct transport_balancer *balancer;
  struct sockaddr_in client_addres;
  socklen_t client_addres_length;
  int fd;
};

int transport_connector_loop(va_list input)
{
  struct transport_connector *connector = va_arg(input, struct transport_connector *);
  struct transport_connector_context *context = (struct transport_connector_context *)connector->context;
  log_info("connector fiber started");
  connector->active = true;
  while (connector->active)
  {
    if (!fiber_channel_is_empty(context->channel))
    {
      void *message;
      if (likely(fiber_channel_get(context->channel, &message) == 0))
      {
        intptr_t fd = (intptr_t)((struct transport_message *)message)->data;
        free(message);
        struct io_uring_sqe *sqe = provide_sqe(&context->ring);
        io_uring_prep_connect(sqe, (int)fd, (struct sockaddr *)&context->client_addres, context->client_addres_length);
        io_uring_sqe_set_data(sqe, (void *)(uint64_t)TRANSPORT_PAYLOAD_CONNECT);
        io_uring_submit(&context->ring);
      }
    }

    int count = 0;
    unsigned int head;
    struct io_uring_cqe *cqe;
    io_uring_for_each_cqe(&context->ring, head, cqe)
    {
      ++count;
      if (unlikely(cqe->res < 0))
      {
        continue;
      }
      if (likely((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_CONNECT)))
      {        
        int fd = cqe->res;
        struct io_uring_sqe *sqe = provide_sqe(&context->ring);
        log_info("send connect to channel");
        struct transport_channel *channel = context->balancer->next(context->balancer);
        io_uring_prep_msg_ring(sqe, channel->ring.ring_fd, fd, (uint64_t)TRANSPORT_PAYLOAD_CONNECT, 0);
        io_uring_submit(&context->ring);
      }
    }
    if (count)
    {
      io_uring_cq_advance(&context->ring, count);
      continue;
    }
    fiber_sleep(0);
  }
  return 0;
}

transport_connector_t *transport_initialize_connector(transport_t *transport,
                                                      transport_controller_t *controller,
                                                      transport_connector_configuration_t *configuration,
                                                      const char *ip,
                                                      int32_t port)
{
  transport_connector_t *connector = malloc(sizeof(transport_connector_t));
  if (!connector)
  {
    return NULL;
  }
  connector->controller = controller;
  connector->transport = transport;
  connector->client_ip = ip;
  connector->client_port = port;

  struct transport_connector_context *context = malloc(sizeof(struct transport_connector_context));

  memset(&context->client_addres, 0, sizeof(context->client_addres));
  context->client_addres.sin_addr.s_addr = inet_addr(connector->client_ip);
  context->client_addres.sin_port = htons(connector->client_port);
  context->client_addres.sin_family = AF_INET;
  context->client_addres_length = sizeof(context->client_addres);
  context->fd = transport_socket_create();
  context->balancer = (struct transport_balancer *)controller->balancer;
  connector->context = context;

  int32_t status = io_uring_queue_init(configuration->ring_size, &context->ring, 0);
  if (status)
  {
    log_error("io_urig init error: %d", status);
    free(&context->ring);
    free(context);
    return NULL;
  }

  context->channel = fiber_channel_new(configuration->ring_size);

  struct transport_message *message = malloc(sizeof(struct transport_message));
  message->action = TRANSPORT_ACTION_ADD_CONNECTOR;
  message->data = (void *)connector;
  transport_controller_send(connector->controller, message);

  return connector;
}

void transport_close_connector(transport_connector_t *connector)
{
  struct transport_connector_context *context = (struct transport_connector_context *)connector->context;
  io_uring_queue_exit(&context->ring);
  free(connector);
}

int32_t transport_connector_connect(transport_connector_t *connector)
{
  struct transport_connector_context *context = (struct transport_connector_context *)connector->context;
  struct transport_message *message = malloc(sizeof(struct transport_message));
  message->channel = context->channel;
  message->action = TRANSPORT_ACTION_SEND;
  message->data = (void *)(intptr_t)context->fd;
  return transport_controller_send(connector->controller, message) ? 0 : -1;
}