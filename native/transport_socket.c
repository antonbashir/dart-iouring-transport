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

int64_t transport_socket_create_tcp(uint64_t flags,
                                    uint32_t socket_receive_buffer_size,
                                    uint32_t socket_send_buffer_size,
                                    uint32_t socket_receive_low_at,
                                    uint32_t socket_send_low_at,
                                    uint16_t ip_ttl,
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
    if (setsockopt(fd, SOL_SOCKET, O_NONBLOCK, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_NONBLOCK;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_CLOCKEXEC)
  {
    if (setsockopt(fd, SOL_SOCKET, O_CLOEXEC, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_CLOCKEXEC;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_REUSEADDR)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_REUSEADDR;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_REUSEPORT)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_REUSEPORT;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_RCVBUF)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &socket_receive_buffer_size, sizeof(socket_receive_buffer_size)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_RCVBUF;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_SNDBUF)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &socket_send_buffer_size, sizeof(socket_send_buffer_size)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_SNDBUF;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_KEEPALIVE)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_KEEPALIVE;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_RCVLOWAT)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_RCVLOWAT, &socket_receive_low_at, sizeof(socket_receive_low_at)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_RCVLOWAT;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_SNDLOWAT)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_SNDLOWAT, &socket_send_low_at, sizeof(socket_send_low_at)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_SNDLOWAT;
    }
  }

  if (flags & TRANSPORT_SOCKET_OPTION_IP_TTL)
  {
    if (setsockopt(fd, SOL_IP, IP_TTL, &ip_ttl, sizeof(ip_ttl)))
    {
      return -TRANSPORT_SOCKET_OPTION_IP_TTL;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_IP_FREEBIND)
  {
    if (setsockopt(fd, SOL_IP, IP_FREEBIND, &activate_option, sizeof(activate_option)))
    {
      return -TRANSPORT_SOCKET_OPTION_IP_FREEBIND;
    }
  }

  if (flags & TRANSPORT_SOCKET_OPTION_TCP_QUICKACK)
  {
    if (setsockopt(fd, SOL_TCP, TCP_QUICKACK, &activate_option, sizeof(activate_option)))
    {
      return -TRANSPORT_SOCKET_OPTION_TCP_QUICKACK;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_DEFER_ACCEPT)
  {
    if (setsockopt(fd, SOL_TCP, TCP_DEFER_ACCEPT, &activate_option, sizeof(activate_option)))
    {
      return -TRANSPORT_SOCKET_OPTION_TCP_DEFER_ACCEPT;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_FASTOPEN)
  {
    if (setsockopt(fd, SOL_TCP, TCP_FASTOPEN, &activate_option, sizeof(activate_option)))
    {
      return -TRANSPORT_SOCKET_OPTION_TCP_FASTOPEN;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_KEEPIDLE)
  {
    if (setsockopt(fd, SOL_TCP, TCP_KEEPIDLE, &tcp_keep_alive_idle, sizeof(tcp_keep_alive_idle)))
    {
      return -TRANSPORT_SOCKET_OPTION_TCP_KEEPIDLE;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_KEEPCNT)
  {
    if (setsockopt(fd, SOL_TCP, TCP_KEEPCNT, &tcp_keep_alive_max_count, sizeof(tcp_keep_alive_max_count)))
    {
      return -TRANSPORT_SOCKET_OPTION_TCP_KEEPCNT;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_KEEPINTVL)
  {
    if (setsockopt(fd, SOL_TCP, TCP_KEEPINTVL, &tcp_keep_alive_individual_count, sizeof(tcp_keep_alive_individual_count)))
    {
      return -TRANSPORT_SOCKET_OPTION_TCP_KEEPINTVL;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_MAXSEG)
  {
    if (setsockopt(fd, SOL_TCP, TCP_MAXSEG, &tcp_max_segment_size, sizeof(tcp_max_segment_size)))
    {
      return -TRANSPORT_SOCKET_OPTION_TCP_MAXSEG;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_NODELAY)
  {
    if (setsockopt(fd, SOL_TCP, TCP_NODELAY, &activate_option, sizeof(activate_option)))
    {
      return -TRANSPORT_SOCKET_OPTION_TCP_NODELAY;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_TCP_SYNCNT)
  {
    if (setsockopt(fd, SOL_TCP, TCP_SYNCNT, &tcp_syn_count, sizeof(tcp_syn_count)))
    {
      return -TRANSPORT_SOCKET_OPTION_TCP_SYNCNT;
    }
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_udp(uint64_t flags,
                                    uint32_t socket_receive_buffer_size,
                                    uint32_t socket_send_buffer_size,
                                    uint32_t socket_receive_low_at,
                                    uint32_t socket_send_low_at,
                                    uint16_t ip_ttl,
                                    struct ip_mreqn *ip_multicast_interface,
                                    uint32_t ip_multicast_ttl)
{
  int32_t activate_option = 1;

  int32_t fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
  if (fd == -1)
  {
    return -1;
  }

  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_NONBLOCK)
  {
    if (setsockopt(fd, SOL_SOCKET, O_NONBLOCK, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_NONBLOCK;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_CLOCKEXEC)
  {
    if (setsockopt(fd, SOL_SOCKET, O_CLOEXEC, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_CLOCKEXEC;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_REUSEADDR)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_REUSEADDR;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_REUSEPORT)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_REUSEPORT;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_RCVBUF)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &socket_receive_buffer_size, sizeof(socket_receive_buffer_size)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_RCVBUF;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_SNDBUF)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &socket_send_buffer_size, sizeof(socket_send_buffer_size)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_SNDBUF;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_BROADCAST)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_BROADCAST;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_RCVLOWAT)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_RCVLOWAT, &socket_receive_low_at, sizeof(socket_receive_low_at)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_RCVLOWAT;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_SNDLOWAT)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_SNDLOWAT, &socket_send_low_at, sizeof(socket_send_low_at)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_SNDLOWAT;
    }
  }

  if (flags & TRANSPORT_SOCKET_OPTION_IP_TTL)
  {
    if (setsockopt(fd, SOL_IP, IP_TTL, &ip_ttl, sizeof(ip_ttl)))
    {
      return -TRANSPORT_SOCKET_OPTION_IP_TTL;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_IP_FREEBIND)
  {
    if (setsockopt(fd, SOL_IP, IP_FREEBIND, &activate_option, sizeof(activate_option)))
    {
      return -TRANSPORT_SOCKET_OPTION_IP_FREEBIND;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_IP_MULTICAST_ALL)
  {
    if (setsockopt(fd, SOL_IP, IP_MULTICAST_ALL, &activate_option, sizeof(activate_option)))
    {
      return -TRANSPORT_SOCKET_OPTION_IP_MULTICAST_ALL;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_IP_MULTICAST_IF)
  {
    if (setsockopt(fd, SOL_IP, IP_MULTICAST_IF, ip_multicast_interface, sizeof(*ip_multicast_interface)))
    {
      return -TRANSPORT_SOCKET_OPTION_IP_MULTICAST_IF;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_IP_MULTICAST_LOOP)
  {
    if (setsockopt(fd, SOL_IP, IP_MULTICAST_LOOP, &activate_option, sizeof(activate_option)))
    {
      return -TRANSPORT_SOCKET_OPTION_IP_MULTICAST_LOOP;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_IP_MULTICAST_TTL)
  {
    if (setsockopt(fd, SOL_IP, IP_MULTICAST_TTL, &ip_multicast_ttl, sizeof(ip_multicast_ttl)))
    {
      return -TRANSPORT_SOCKET_OPTION_IP_MULTICAST_TTL;
    }
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_unix_stream(uint64_t flags,
                                            uint32_t socket_receive_buffer_size,
                                            uint32_t socket_send_buffer_size,
                                            uint32_t socket_receive_low_at,
                                            uint32_t socket_send_low_at)
{
  int32_t activate_option = 1;

  int32_t fd = socket(AF_UNIX, SOCK_STREAM, 0);
  if (fd == -1)
  {
    return -1;
  }

  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_NONBLOCK)
  {
    if (setsockopt(fd, SOL_SOCKET, O_NONBLOCK, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_NONBLOCK;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_CLOCKEXEC)
  {
    if (setsockopt(fd, SOL_SOCKET, O_CLOEXEC, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_CLOCKEXEC;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_RCVBUF)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &socket_receive_buffer_size, sizeof(socket_receive_buffer_size)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_RCVBUF;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_SNDBUF)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &socket_send_buffer_size, sizeof(socket_send_buffer_size)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_SNDBUF;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_KEEPALIVE)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_KEEPALIVE;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_RCVLOWAT)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_RCVLOWAT, &socket_receive_low_at, sizeof(socket_receive_low_at)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_RCVLOWAT;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_SNDLOWAT)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_SNDLOWAT, &socket_send_low_at, sizeof(socket_send_low_at)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_SNDLOWAT;
    }
  }

  return (uint32_t)fd;
}

int32_t transport_socket_create_unix_dgram(uint64_t flags,
                                           uint32_t socket_receive_buffer_size,
                                           uint32_t socket_send_buffer_size,
                                           uint32_t socket_receive_low_at,
                                           uint32_t socket_send_low_at)
{
  int32_t activate_option = 1;

  int32_t fd = socket(AF_UNIX, SOCK_DGRAM, 0);
  if (fd == -1)
  {
    return -1;
  }

  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_NONBLOCK)
  {
    if (setsockopt(fd, SOL_SOCKET, O_NONBLOCK, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_NONBLOCK;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_CLOCKEXEC)
  {
    if (setsockopt(fd, SOL_SOCKET, O_CLOEXEC, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_CLOCKEXEC;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_BROADCAST)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &activate_option, sizeof(int)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_BROADCAST;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_RCVBUF)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &socket_receive_buffer_size, sizeof(socket_receive_buffer_size)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_RCVBUF;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_SNDBUF)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &socket_send_buffer_size, sizeof(socket_send_buffer_size)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_SNDBUF;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_RCVLOWAT)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_RCVLOWAT, &socket_receive_low_at, sizeof(socket_receive_low_at)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_RCVLOWAT;
    }
  }
  if (flags & TRANSPORT_SOCKET_OPTION_SOCKET_SNDLOWAT)
  {
    if (setsockopt(fd, SOL_SOCKET, SO_SNDLOWAT, &socket_send_low_at, sizeof(socket_send_low_at)))
    {
      return -TRANSPORT_SOCKET_OPTION_SOCKET_SNDLOWAT;
    }
  }

  return (uint32_t)fd;
}

struct ip_mreqn *transport_socket_create_multicast_request(const char *multicast_group_address, const char *multicast_local_address, int interface_index)
{
  struct ip_mreqn *request = malloc(sizeof(struct ip_mreqn));
  request->imr_multiaddr.s_addr = inet_addr(multicast_group_address);
  request->imr_address.s_addr = inet_addr(multicast_local_address);
  request->imr_ifindex = interface_index;
  return request;
}