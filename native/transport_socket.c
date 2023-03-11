#include "transport_socket.h"
#include <stdio.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <liburing.h>
#include <string.h>
#include <errno.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdint.h>

int32_t transport_socket_create(uint32_t max_connections, uint32_t receive_buffer_size, uint32_t send_buffer_size)
{
  int32_t option = 1;

  int32_t fd = socket(AF_INET, SOCK_STREAM | O_NONBLOCK | SOCK_CLOEXEC, 0);
  if (fd == -1)
  {
    return -1;
  }

  int32_t result = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &option, sizeof(int));
  if (result < 0)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &option, sizeof(option));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &receive_buffer_size, sizeof(receive_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &send_buffer_size, sizeof(send_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &option, sizeof(option));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, IPPROTO_TCP, TCP_QUICKACK, &option, sizeof(option));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, IPPROTO_TCP, TCP_FASTOPEN, &max_connections, sizeof(max_connections));
  if (result == -1)
  {
    return -1;
  }
  return (uint32_t)fd;
}

int32_t transport_socket_bind(int32_t server_socket_fd, const char *ip, int32_t port, int32_t max_connections)
{
  struct sockaddr_in server_address;
  memset(&server_address, 0, sizeof(server_address));
  server_address.sin_family = AF_INET;
  server_address.sin_port = htons(port);
  server_address.sin_addr.s_addr = inet_addr(ip);

  int32_t result = bind(server_socket_fd, (const struct sockaddr *)&server_address, sizeof(server_address));
  if (result < 0)
  {
    return -1;
  }

  result = listen(server_socket_fd, max_connections);
  if (result < 0)
  {
    return -1;
  }

  return result;
}
