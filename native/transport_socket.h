#ifndef transport_SOCKET_H_INCLUDED
#define transport_SOCKET_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>

#if defined(__cplusplus)
extern "C"
{
#endif
  int32_t transport_socket_create(uint32_t max_connections, uint32_t receive_buffer_size, uint32_t send_buffer_size);
  int32_t transport_socket_bind(int32_t server_socket_fd, const char *ip, int32_t port, int32_t max_connections);
#if defined(__cplusplus)
}
#endif

#endif
