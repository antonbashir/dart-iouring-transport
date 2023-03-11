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
#include "transport_connector.h"
#include "transport_common.h"
#include "transport_constants.h"
#include "transport_channel.h"
#include "transport_socket.h"

struct transport_connector_context
{
  struct io_uring ring;
  struct sockaddr_in client_addres;
  socklen_t client_addres_length;
  int fd;
};

transport_connector_t *transport_initialize_connector(transport_t *transport,
                                                      transport_connector_configuration_t *configuration,
                                                      const char *ip,
                                                      int32_t port)
{
  transport_connector_t *connector = malloc(sizeof(transport_connector_t));
  if (!connector)
  {
    return NULL;
  }
  connector->transport = transport;
  connector->client_ip = ip;
  connector->client_port = port;

  struct transport_connector_context *context = malloc(sizeof(struct transport_connector_context));

  memset(&context->client_addres, 0, sizeof(context->client_addres));
  context->client_addres.sin_addr.s_addr = inet_addr(connector->client_ip);
  context->client_addres.sin_port = htons(connector->client_port);
  context->client_addres.sin_family = AF_INET;
  context->client_addres_length = sizeof(context->client_addres);
  //context->fd = transport_socket_create();
  connector->context = context;

  int32_t status = io_uring_queue_init(configuration->ring_size, &context->ring, 0);
  if (status)
  {
    transport_error("io_urig init error: %d", status);
    free(&context->ring);
    free(context);
    return NULL;
  }

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
  return 0;
}