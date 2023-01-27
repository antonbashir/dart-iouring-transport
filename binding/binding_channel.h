#ifndef BINDING_CHANNEL_H_INCLUDED
#define BINDING_CHANNEL_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include "small/include/small/ibuf.h"
#include "small/include/small/obuf.h"
#include "small/include/small/small.h"
#include "binding_transport.h"
#include "binding_listener.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_channel_configuration
  {
    size_t buffer_initial_capacity;
    size_t buffer_limit;
  } transport_channel_configuration_t;

  typedef struct transport_channel
  {
    transport_t *transport;
    transport_listener_t *listener;

    struct mempool data_payload_pool;
    struct mempool accept_payload_pool;

    struct ibuf read_buffers[2];
    struct ibuf *current_read_buffer;

    struct ibuf write_buffers[2];
    struct ibuf *current_write_buffer;

    size_t current_read_size;
    size_t current_write_size;

    size_t buffer_initial_capacity;
    size_t buffer_limit;

    Dart_Port accept_port;
    Dart_Port connect_port;
    Dart_Port read_port;
    Dart_Port write_port;

    int32_t fd;

    int32_t payload_buffer_size;
  } transport_channel_t;

  transport_channel_t *transport_initialize_channel(transport_t *transport,
                                                    transport_listener_t *listener,
                                                    transport_channel_configuration_t *configuration,
                                                    Dart_Port accept_port,
                                                    Dart_Port connect_port,
                                                    Dart_Port read_port,
                                                    Dart_Port write_port);
  void transport_close_channel(transport_channel_t *channel);

  int32_t transport_channel_queue_read(transport_channel_t *channel, uint64_t offset);
  int32_t transport_channel_queue_write(transport_channel_t *channel, uint32_t payload_size, uint64_t offset);
  int32_t transport_channel_queue_accept(transport_channel_t *channel, int32_t server_socket_fd);
  int32_t transport_channel_queue_connect(transport_channel_t *channel, int32_t socket_fd, const char *ip, int32_t port);

  void *transport_channel_extract_write_buffer(transport_channel_t *channel, transport_data_payload_t *message);
  void *transport_channel_extract_read_buffer(transport_channel_t *channel, transport_data_payload_t *message);

  void *transport_channel_prepare_read(transport_channel_t *channel, size_t size);
  void *transport_channel_prepare_write(transport_channel_t *channel, size_t size);

  transport_accept_payload_t *transport_channel_allocate_accept_payload(transport_channel_t *channel);
  transport_data_payload_t *transport_channel_allocate_data_payload(transport_channel_t *channel);
  void transport_channel_free_accept_payload(transport_channel_t *channel, transport_accept_payload_t *payload);
  void transport_channel_free_data_payload(transport_channel_t *channel, transport_data_payload_t *payload);
#if defined(__cplusplus)
}
#endif

#endif
