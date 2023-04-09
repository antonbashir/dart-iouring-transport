#ifndef TRANSPORT_CONSTANTS_H
#define TRANSPORT_CONSTANTS_H

#include <stdint.h>

#if defined(__cplusplus)
extern "C"
{
#endif

#define TRANSPORT_EVENT_READ ((uint16_t)1 << 0)
#define TRANSPORT_EVENT_WRITE ((uint16_t)1 << 1)
#define TRANSPORT_EVENT_RECEIVE_MESSAGE ((uint16_t)1 << 2)
#define TRANSPORT_EVENT_SEND_MESSAGE ((uint16_t)1 << 3)
#define TRANSPORT_EVENT_ACCEPT ((uint16_t)1 << 4)
#define TRANSPORT_EVENT_CONNECT ((uint16_t)1 << 5)
#define TRANSPORT_EVENT_CLIENT ((uint16_t)1 << 6)
#define TRANSPORT_EVENT_CUSTOM ((uint16_t)1 << 7)
#define TRANSPORT_EVENT_FILE ((uint16_t)1 << 8)

#define TRANSPORT_BUFFER_AVAILABLE -2
#define TRANSPORT_BUFFER_USED -1

#define TRANSPORT_SOCKET_OPTION_SOCKET_NONBLOCK ((uint32_t)1 << 0)
#define TRANSPORT_SOCKET_OPTION_SOCKET_CLOCKEXEC ((uint32_t)1 << 1)
#define TRANSPORT_SOCKET_OPTION_SOCKET_REUSEADDR ((uint32_t)1 << 2)
#define TRANSPORT_SOCKET_OPTION_SOCKET_REUSEPORT ((uint32_t)1 << 3)
#define TRANSPORT_SOCKET_OPTION_SOCKET_RCVBUF ((uint32_t)1 << 4)
#define TRANSPORT_SOCKET_OPTION_SOCKET_SNDBUF ((uint32_t)1 << 5)
#define TRANSPORT_SOCKET_OPTION_SOCKET_BUSY_POLL ((uint32_t)1 << 6)
#define TRANSPORT_SOCKET_OPTION_IP_TTL ((uint32_t)1 << 7)
#define TRANSPORT_SOCKET_OPTION_TCP_CORK ((uint32_t)1 << 8)
#define TRANSPORT_SOCKET_OPTION_TCP_QUICKACK ((uint32_t)1 << 9)
#define TRANSPORT_SOCKET_OPTION_TCP_DEFER_ACCEPT ((uint32_t)1 << 10)
#define TRANSPORT_SOCKET_OPTION_TCP_NOTSENT_LOWAT ((uint32_t)1 << 11)
#define TRANSPORT_SOCKET_OPTION_TCP_FASTOPEN ((uint32_t)1 << 12)
#define TRANSPORT_SOCKET_OPTION_TCP_KEEPIDLE ((uint32_t)1 << 13)
#define TRANSPORT_SOCKET_OPTION_TCP_KEEPCNT ((uint32_t)1 << 14)
#define TRANSPORT_SOCKET_OPTION_TCP_USER_TIMEOUT ((uint32_t)1 << 15)
#define TRANSPORT_SOCKET_OPTION_TCP_FREEBIND ((uint32_t)1 << 16)
#define TRANSPORT_SOCKET_OPTION_TCP_TRANSPARENT ((uint32_t)1 << 17)
#define TRANSPORT_SOCKET_OPTION_TCP_RECVORIGDSTADDR ((uint32_t)1 << 18)
#define TRANSPORT_SOCKET_OPTION_UDP_CORK ((uint32_t)1 << 19)

  typedef enum transport_socket_family
  {
    INET = 0,
    UNIX,
  } transport_socket_family_t;

#if defined(__cplusplus)
}
#endif

#endif