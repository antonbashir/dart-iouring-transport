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
#include "binding_payload.h"
#include "binding_socket.h"
#include "fiber.h"

struct transport_acceptor_context
{
  int fd;
  struct sockaddr_in server_address;
  socklen_t server_address_length;
  const char *ip;
  int32_t port;
  int32_t backlog;
};

transport_acceptor_t *transport_initialize_acceptor(transport_acceptor_configuration_t *configuration,
                                                    const char *ip, int32_t port)
{
  transport_acceptor_t *acceptor = malloc(sizeof(transport_acceptor_t));
  if (!acceptor)
  {
    return NULL;
  }
  struct transport_acceptor_context *context = malloc(sizeof(struct transport_acceptor_context));
  acceptor->context = context;
  memset(&context->server_address, 0, sizeof(context->server_address));
  context->server_address.sin_addr.s_addr = inet_addr(ip);
  context->server_address.sin_port = htons(port);
  context->server_address.sin_family = AF_INET;
  context->server_address_length = sizeof(context->server_address);
  context->backlog = configuration->backlog;
  context->ip = ip;
  context->port = port;
  context->fd = transport_socket_create();
  if (transport_socket_bind(context->fd, context->ip, context->port, context->backlog))
  {
    free(acceptor);
    return NULL;
  }

  log_info("acceptor initialized");
  return acceptor;
}

transport_acceptor_t *transport_acceptor_share(transport_acceptor_t *source, struct io_uring *ring)
{
  struct transport_acceptor_context *source_context = (struct transport_acceptor_context *)source->context;
  transport_acceptor_t *acceptor = malloc(sizeof(transport_acceptor_t));
  if (!acceptor)
  {
    return NULL;
  }
  struct transport_acceptor_context *context = malloc(sizeof(struct transport_acceptor_context));
  acceptor->context = context;
  context->server_address = source_context->server_address;
  context->server_address_length = source_context->server_address_length;
  context->backlog = source_context->backlog;
  context->ip = source_context->ip;
  context->port = source_context->port;
  context->fd = source_context->fd;
  acceptor->ring = ring;
  log_info("acceptor shared");
  return acceptor;
}

int transport_acceptor_accept(struct transport_acceptor *acceptor)
{
  struct transport_acceptor_context *context = (struct transport_acceptor_context *)acceptor->context;
  struct io_uring_sqe *sqe = provide_sqe(acceptor->ring);
  io_uring_prep_accept(sqe, context->fd, (struct sockaddr *)&context->server_address, &context->server_address_length, 0);
  io_uring_sqe_set_data64(sqe, (uint64_t)TRANSPORT_PAYLOAD_ACCEPT);
  return io_uring_submit(acceptor->ring);
}

void transport_close_acceptor(transport_acceptor_t *acceptor)
{
  struct transport_acceptor_context *context = (struct transport_acceptor_context *)acceptor->context;
  io_uring_queue_exit(acceptor->ring);
  free(acceptor);
}
