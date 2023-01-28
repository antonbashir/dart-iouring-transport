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
#include "binding_controller.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_channel_configuration
  {
    size_t buffer_initial_capacity;
    size_t buffer_limit;
    int32_t payload_buffer_size;
  } transport_channel_configuration_t;

  typedef struct transport_channel
  {
    transport_t *transport;
    transport_controller_t *controller;

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

    Dart_Port read_port;
    Dart_Port write_port;

    int32_t fd;

    int32_t payload_buffer_size;
  } transport_channel_t;

  transport_channel_t *transport_initialize_channel(transport_t *transport,
                                                    transport_controller_t *controller,
                                                    transport_channel_configuration_t *configuration,
                                                    int fd,
                                                    Dart_Port read_port,
                                                    Dart_Port write_port);
  void transport_close_channel(transport_channel_t *channel);

  int32_t transport_channel_queue_read(transport_channel_t *channel, uint64_t offset);
  int32_t transport_channel_queue_write(transport_channel_t *channel, uint32_t payload_size, uint64_t offset);

  void *transport_channel_extract_write_buffer(transport_channel_t *channel, transport_data_payload_t *message);
  void *transport_channel_extract_read_buffer(transport_channel_t *channel, transport_data_payload_t *message);

  void *transport_channel_prepare_read(transport_channel_t *channel);
  void *transport_channel_prepare_write(transport_channel_t *channel);

  transport_data_payload_t *transport_channel_allocate_data_payload(transport_channel_t *channel);
  void transport_channel_free_data_payload(transport_channel_t *channel, transport_data_payload_t *payload);
#if defined(__cplusplus)
}
#endif

#endif
