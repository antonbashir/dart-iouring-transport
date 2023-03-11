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
#include "transport_acceptor.h"
#include "transport_common.h"
#include "transport_constants.h"
#include "transport_socket.h"

transport_acceptor_t *transport_acceptor_initialize(transport_acceptor_configuration_t *configuration,
                                                    const char *ip, int32_t port)
{
  transport_acceptor_t *acceptor = malloc(sizeof(transport_acceptor_t));
  if (!acceptor)
  {
    return NULL;
  }
  memset(&acceptor->server_address, 0, sizeof(acceptor->server_address));
  acceptor->server_address.sin_addr.s_addr = inet_addr(ip);
  acceptor->server_address.sin_port = htons(port);
  acceptor->server_address.sin_family = AF_INET;
  acceptor->server_address_length = sizeof(acceptor->server_address);
  acceptor->fd = transport_socket_create(configuration->max_connections, configuration->receive_buffer_size, configuration->send_buffer_size);
  if (transport_socket_bind(acceptor->fd, ip, port, configuration->max_connections))
  {
    free(acceptor);
    return NULL;
  }
  struct io_uring *ring = malloc(sizeof(struct io_uring));
  int32_t status = io_uring_queue_init(configuration->ring_size, ring, configuration->ring_flags);
  if (status)
  {
    transport_error("[acceptor]: io_urig init error = %d", status);
    free(ring);
    free(acceptor);
    return NULL;
  }
  acceptor->ring = ring;
  transport_info("[acceptor]: initialized");
  return acceptor;
}

void transport_acceptor_shutdown(transport_acceptor_t *acceptor)
{
  io_uring_queue_exit(acceptor->ring);
  shutdown(acceptor->fd, SHUT_RDWR);
  free(acceptor->ring);
  free(acceptor);
  transport_info("[acceptor]: shutdown");
}