#ifndef TRANSPORT_SOCKET_H_INCLUDED
#define TRANSPORT_SOCKET_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>

#if defined(__cplusplus)
extern "C"
{
#endif
  int32_t transport_socket_create_tcp(uint32_t receive_buffer_size, uint32_t send_buffer_size);
  int32_t transport_socket_create_udp(uint32_t receive_buffer_size, uint32_t send_buffer_size);
  int32_t transport_socket_create_unix_stream(uint32_t receive_buffer_size, uint32_t send_buffer_size);
  int32_t transport_socket_create_unix_dgram(uint32_t receive_buffer_size, uint32_t send_buffer_size);
  struct ip_mreqn* transport_socket_create_multicast_request(const char* multicast_group_address, const char* multicast_local_address,  int interface_index);
#if defined(__cplusplus)
}
#endif

#endif
