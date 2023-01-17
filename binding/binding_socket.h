#ifndef BINDING_SOCKET_H_INCLUDED
#define BINDING_SOCKET_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>

#if defined(__cplusplus)
extern "C"
{
#endif
  int32_t transport_socket_create();
  int32_t transport_socket_bind(int32_t server_socket_fd, const char* ip, int32_t port, int32_t backlog);
#if defined(__cplusplus)
}
#endif

#endif
