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
    size_t buffers_count;
    int32_t buffer_size;
    uint32_t ring_size;
  } transport_channel_configuration_t;

  typedef struct transport_channel
  {
    struct io_uring ring;

    transport_t *transport;
    transport_controller_t *controller;

    size_t buffer_initial_capacity;
    size_t buffer_limit;
    size_t buffers_count;

    Dart_Port read_port;
    Dart_Port write_port;

    void* context;

    int32_t payload_buffer_size;
  } transport_channel_t;

  transport_channel_t *transport_initialize_channel(transport_t *transport,
                                                    transport_controller_t *controller,
                                                    transport_channel_configuration_t *configuration,
                                                    Dart_Port read_port,
                                                    Dart_Port write_port);
  int transport_channel_loop(va_list input);

  void transport_close_channel(transport_channel_t *channel);

  int32_t transport_channel_queue_read(transport_channel_t *channel, uint64_t offset);
  int32_t transport_channel_queue_write(transport_channel_t *channel, uint32_t payload_size, uint64_t offset);

  void *transport_channel_extract_write_buffer(transport_channel_t *channel, transport_data_payload_t *message);
  void *transport_channel_extract_read_buffer(transport_channel_t *channel, transport_data_payload_t *message);

  void *transport_channel_prepare_read(transport_channel_t *channel);
  void *transport_channel_prepare_write(transport_channel_t *channel);
#if defined(__cplusplus)
}
#endif

#endif
