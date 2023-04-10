#include "transport_constants.h"
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

int32_t transport_socket_create_server_tcp(uint64_t flags,
                                           uint32_t socket_receive_buffer_size,
                                           uint32_t socket_send_buffer_size,
                                           uint32_t socket_receive_low_at,
                                           uint32_t socket_send_low_at,
                                           uint16_t ip_ttl,
                                           struct ip_mreqn ip_multicast_interface,
                                           uint32_t ip_multicast_ttl,
                                           uint32_t tcp_keep_alive_idle,
                                           uint32_t tcp_keep_alive_max_count,
                                           uint32_t tcp_keep_alive_individual_count,
                                           uint32_t tcp_max_segment_size,
                                           uint16_t tcp_syn_count)
{
  int32_t activate_option = 1;

  int32_t fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (fd == -1)
  {
    return -1;
  }

  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_NONBLOCK)
  {
    if (setsockopt(fd, SOL_SOCKET, O_NONBLOCK, &activate_option, sizeof(int)) == -1)
    {
      return -1;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_CLOCKEXEC)
  {
    setsockopt(fd, SOL_SOCKET, O_CLOEXEC, &activate_option, sizeof(int));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_REUSEADDR)
  {
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &activate_option, sizeof(int));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_REUSEPORT)
  {
    setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &activate_option, sizeof(int));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_RCVBUF)
  {
    setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &socket_receive_buffer_size, sizeof(socket_receive_buffer_size));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_SNDBUF)
  {
    setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &socket_send_buffer_size, sizeof(socket_send_buffer_size));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_BROADCAST)
  {
    setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &activate_option, sizeof(int));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_KEEPALIVE)
  {
    setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &activate_option, sizeof(int));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_RCVLOWAT)
  {
    setsockopt(fd, SOL_SOCKET, SO_RCVLOWAT, &socket_receive_low_at, sizeof(socket_receive_low_at));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_SNDLOWAT)
  {
    setsockopt(fd, SOL_SOCKET, SO_SNDLOWAT, &socket_send_low_at, sizeof(socket_send_low_at));
  }

  if (flags & TRANSPORT_SOCKET_OPTION_IP_TTL)
  {
    setsockopt(fd, SOL_IP, IP_TTL, &ip_ttl, sizeof(ip_ttl));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_IP_FREEBIND)
  {
    setsockopt(fd, SOL_IP, IP_FREEBIND, &activate_option, sizeof(activate_option));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_IP_MULTICAST_ALL)
  {
    setsockopt(fd, SOL_IP, IP_MULTICAST_ALL, &activate_option, sizeof(activate_option));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_IP_MULTICAST_IF)
  {
    setsockopt(fd, SOL_IP, IP_MULTICAST_IF, &ip_multicast_interface, sizeof(ip_multicast_interface));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_IP_MULTICAST_LOOP)
  {
    setsockopt(fd, SOL_IP, IP_MULTICAST_LOOP, &activate_option, sizeof(activate_option));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_IP_MULTICAST_TTL)
  {
    setsockopt(fd, SOL_IP, IP_MULTICAST_TTL, &ip_multicast_ttl, sizeof(ip_multicast_ttl));
  }

  if (flags & TRANSPORT_SOCKET_OPTION_TCP_QUICKACK)
  {
    setsockopt(fd, SOL_TCP, TCP_QUICKACK, &activate_option, sizeof(activate_option));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_DEFER_ACCEPT)
  {
    setsockopt(fd, SOL_TCP, TCP_DEFER_ACCEPT, &activate_option, sizeof(activate_option));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_FASTOPEN)
  {
    setsockopt(fd, SOL_TCP, TCP_FASTOPEN, &activate_option, sizeof(activate_option));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_KEEPIDLE)
  {
    setsockopt(fd, SOL_TCP, TCP_KEEPIDLE, &tcp_keep_alive_idle, sizeof(tcp_keep_alive_idle));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_KEEPCNT)
  {
    setsockopt(fd, SOL_TCP, TCP_KEEPCNT, &tcp_keep_alive_max_count, sizeof(tcp_keep_alive_max_count));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_KEEPINTVL)
  {
    setsockopt(fd, SOL_TCP, TCP_KEEPINTVL, &tcp_keep_alive_individual_count, sizeof(tcp_keep_alive_individual_count));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_MAXSEG)
  {
    setsockopt(fd, SOL_TCP, TCP_MAXSEG, &tcp_max_segment_size, sizeof(tcp_max_segment_size));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_NODELAY)
  {
    setsockopt(fd, SOL_TCP, TCP_NODELAY, &activate_option, sizeof(activate_option));
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_SYNCNT)
  {
    setsockopt(fd, SOL_TCP, TCP_SYNCNT, &tcp_syn_count, sizeof(tcp_syn_count));
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_server_udp(uint32_t socket_receive_buffer_size, uint32_t socket_send_buffer_size)
{
  int32_t activate_option = 1;

  int32_t fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (fd == -1)
  {
    return -1;
  }

  int32_t result = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &activate_option, sizeof(int));
  if (result < 0)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &socket_receive_buffer_size, sizeof(socket_receive_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &socket_send_buffer_size, sizeof(socket_send_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_server_unix_stream(uint32_t socket_receive_buffer_size, uint32_t socket_send_buffer_size)
{
  int32_t activate_option = 1;

  int32_t fd = socket(AF_UNIX, SOCK_STREAM, 0);
  if (fd == -1)
  {
    return -1;
  }

  int32_t result = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &socket_receive_buffer_size, sizeof(socket_receive_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &socket_send_buffer_size, sizeof(socket_send_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_server_unix_dgram(uint32_t socket_receive_buffer_size, uint32_t socket_send_buffer_size)
{
  int32_t activate_option = 1;

  int32_t fd = socket(AF_UNIX, SOCK_DGRAM, 0);
  if (fd == -1)
  {
    return -1;
  }

  int32_t result = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &socket_receive_buffer_size, sizeof(socket_receive_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &socket_send_buffer_size, sizeof(socket_send_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_client_tcp(
    uint64_t flags,
    uint32_t socket_receive_buffer_size,
    uint32_t socket_send_buffer_size,
    uint32_t socket_receive_low_at,
    uint32_t socket_send_low_at,
    uint16_t ip_ttl,
    struct ip_mreqn ip_multicast_interface,
    uint32_t ip_multicast_ttl,
    uint32_t tcp_keep_alive_idle,
    uint32_t tcp_keep_alive_max_count,
    uint32_t tcp_keep_alive_individual_count,
    uint32_t tcp_max_segment_size,
    uint16_t tcp_syn_count)
{
  int32_t activate_option = 1;

  int32_t fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (fd == -1)
  {
    return -1;
  }

  int32_t result = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &socket_receive_buffer_size, sizeof(socket_receive_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &socket_send_buffer_size, sizeof(socket_send_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_client_udp(uint32_t socket_receive_buffer_size, uint32_t socket_send_buffer_size)
{
  int32_t activate_option = 1;

  int32_t fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (fd == -1)
  {
    return -1;
  }

  int32_t result = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &socket_receive_buffer_size, sizeof(socket_receive_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &socket_send_buffer_size, sizeof(socket_send_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_client_unix_dgram(uint32_t socket_receive_buffer_size, uint32_t socket_send_buffer_size)
{
  int32_t activate_option = 1;

  int32_t fd = socket(AF_UNIX, SOCK_DGRAM, 0);
  if (fd == -1)
  {
    return -1;
  }

  int32_t result = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &socket_receive_buffer_size, sizeof(socket_receive_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &socket_send_buffer_size, sizeof(socket_send_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_client_unix_stream(uint32_t socket_receive_buffer_size, uint32_t socket_send_buffer_size)
{
  int32_t activate_option = 1;

  int32_t fd = socket(AF_UNIX, SOCK_STREAM, 0);
  if (fd == -1)
  {
    return -1;
  }

  int32_t result = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &activate_option, sizeof(int));
  if (result < 0)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &socket_receive_buffer_size, sizeof(socket_receive_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  result = setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &socket_send_buffer_size, sizeof(socket_send_buffer_size));
  if (result == -1)
  {
    return -1;
  }

  return (uint32_t)fd;
}