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

int32_t transport_socket_create_server_tcp(uint32_t receive_buffer_size, uint32_t send_buffer_size)
{
  int32_t option = 1;

  int32_t fd = socket(AF_INET, SOCK_STREAM | O_NONBLOCK | SOCK_CLOEXEC, IPPROTO_TCP);
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

  return (uint32_t)fd;
}

int32_t transport_socket_create_server_udp(uint32_t receive_buffer_size, uint32_t send_buffer_size)
{
  int32_t option = 1;

  int32_t fd = socket(AF_INET, SOCK_DGRAM | SOCK_CLOEXEC, IPPROTO_UDP);
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

  return (uint32_t)fd;
}

int32_t transport_socket_create_server_unix_stream(uint32_t receive_buffer_size, uint32_t send_buffer_size)
{
  int32_t option = 1;

  int32_t fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
  if (fd == -1)
  {
    return -1;
  }

  int32_t result = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &receive_buffer_size, sizeof(receive_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &send_buffer_size, sizeof(send_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_server_unix_dgram(uint32_t receive_buffer_size, uint32_t send_buffer_size)
{
  int32_t option = 1;

  int32_t fd = socket(AF_UNIX, SOCK_DGRAM | SOCK_CLOEXEC, 0);
  if (fd == -1)
  {
    return -1;
  }

  int32_t result = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &receive_buffer_size, sizeof(receive_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &send_buffer_size, sizeof(send_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_client_tcp(uint32_t receive_buffer_size, uint32_t send_buffer_size)
{
  int32_t option = 1;

  int32_t fd = socket(AF_INET, SOCK_STREAM | O_NONBLOCK, IPPROTO_TCP);
  if (fd == -1)
  {
    return -1;
  }

  int32_t result = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &receive_buffer_size, sizeof(receive_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &send_buffer_size, sizeof(send_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_client_udp(uint32_t receive_buffer_size, uint32_t send_buffer_size)
{
  int32_t option = 1;

  int32_t fd = socket(AF_INET, SOCK_DGRAM | O_CLOEXEC, IPPROTO_UDP);
  if (fd == -1)
  {
    return -1;
  }

  int32_t result = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &receive_buffer_size, sizeof(receive_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &send_buffer_size, sizeof(send_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_client_unix_dgram(uint32_t receive_buffer_size, uint32_t send_buffer_size)
{
  int32_t option = 1;

  int32_t fd = socket(AF_UNIX, SOCK_DGRAM | O_CLOEXEC, 0);
  if (fd == -1)
  {
    return -1;
  }

  int32_t result = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &receive_buffer_size, sizeof(receive_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &send_buffer_size, sizeof(send_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_client_unix_stream(uint32_t receive_buffer_size, uint32_t send_buffer_size)
{
  int32_t option = 1;

  int32_t fd = socket(AF_UNIX, SOCK_STREAM | O_CLOEXEC, 0);
  if (fd == -1)
  {
    return -1;
  }

  int32_t result = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &option, sizeof(int));
  if (result < 0)
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

  return (uint32_t)fd;
}