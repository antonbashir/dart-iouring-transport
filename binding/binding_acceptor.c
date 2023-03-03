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
#include "binding_socket.h"
#include "fiber.h"

struct transport_acceptor_context
{
  struct io_uring* ring;
  struct sockaddr_in server_address;
  socklen_t server_address_length;
  int fd;
};

transport_acceptor_t *transport_initialize_acceptor(transport_t *transport,
                                                    transport_acceptor_configuration_t *configuration,
                                                    const char *ip,
                                                    int32_t port)
{
  transport_acceptor_t *acceptor = malloc(sizeof(transport_acceptor_t));
  if (!acceptor)
  {
    return NULL;
  }
  acceptor->transport = transport;
  acceptor->server_ip = ip;
  acceptor->server_port = port;

  struct transport_acceptor_context *context = malloc(sizeof(struct transport_acceptor_context));
  memset(&context->server_address, 0, sizeof(context->server_address));
  context->server_address.sin_addr.s_addr = inet_addr(acceptor->server_ip);
  context->server_address.sin_port = htons(acceptor->server_port);
  context->server_address.sin_family = AF_INET;
  context->server_address_length = sizeof(context->server_address);
  context->fd = transport_socket_create();
  if (transport_socket_bind(context->fd, ip, port, configuration->backlog))
  {
    return NULL;
  }

  acceptor->context = context;
  log_info("acceptor initialized");
  return acceptor;
}

int transport_acceptor_accept(struct transport_acceptor *acceptor)
{
  struct transport_acceptor_context *context = (struct transport_acceptor_context *)acceptor->context;
  struct io_uring_sqe *sqe = provide_sqe(context->ring);
  io_uring_prep_accept(sqe, context->fd, (struct sockaddr *)&context->server_address, &context->server_address_length, 0);
  io_uring_sqe_set_data64(sqe, (uint64_t)TRANSPORT_PAYLOAD_ACCEPT);
  return io_uring_submit(context->ring);
}

void transport_close_acceptor(transport_acceptor_t *acceptor)
{
  struct transport_acceptor_context *context = (struct transport_acceptor_context *)acceptor->context;
  io_uring_queue_exit(context->ring);
  free(acceptor);
}

void transport_acceptor_register(transport_acceptor_t *acceptor, struct io_uring *ring)
{
  struct transport_acceptor_context *context = (struct transport_acceptor_context *)acceptor->context;
  context->ring = ring;
}