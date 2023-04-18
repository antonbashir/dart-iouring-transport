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
#include <pthread.h>
#include <sys/time.h>
#include "transport.h"
#include "transport_common.h"
#include "transport_constants.h"
#include "transport_listener.h"
#include "transport_server.h"
#include "small/include/small/rlist.h"

void transport_initialize(transport_t *transport,
                          transport_listener_configuration_t *listener_configuration,
                          transport_worker_configuration_t *inbound_worker_configuration,
                          transport_worker_configuration_t *outbound_worker_configuration)
{
  transport->listener_configuration = listener_configuration;
  transport->inbound_worker_configuration = inbound_worker_configuration;
  transport->outbound_worker_configuration = outbound_worker_configuration;
}

void transport_destroy(transport_t *transport)
{
  free(transport->listener_configuration);
  free(transport->inbound_worker_configuration);
  free(transport->outbound_worker_configuration);
  free(transport);
}

void transport_cqe_advance(struct io_uring *ring, int count)
{
  io_uring_cq_advance(ring, count);
}

struct io_uring_cqe **transport_allocate_cqes(uint32_t cqe_count)
{
  return malloc(sizeof(struct io_uring_cqe) * cqe_count);
}

void transport_close_descritor(int fd)
{
  shutdown(fd, SHUT_RDWR);
  close(fd);
}

char *transport_address_to_string(struct sockaddr *address, transport_socket_family_t family)
{
  return family == INET ? inet_ntoa(((struct sockaddr_in *)address)->sin_addr) : ((struct sockaddr_un *)address)->sun_path;
}

char *transport_socket_fd_to_address(int fd, transport_socket_family_t family)
{
  socklen_t length;
  if (family == INET)
  {
    struct sockaddr_in address;
    if (getpeername(fd, &address, length))
    {
      return NULL;
    }
    char *name = inet_ntoa(address.sin_addr);
    char *name_copy = malloc(strlen(name));
    strcpy(name, name_copy);
    return name_copy;
  }
  struct sockaddr_un address;
  if (getpeername(fd, &address, length))
  {
    return NULL;
  }
  char *name = address.sun_path;
  char *name_copy = malloc(strlen(name));
  strcpy(name, name_copy);
  return name_copy;
}

int transport_socket_fd_to_port(int fd)
{
  socklen_t length;
  struct sockaddr_in address;
  getpeername(fd, &address, length);
  return address.sin_port;
}