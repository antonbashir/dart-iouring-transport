#ifndef BINDING_CHANNEL_H_INCLUDED
#define BINDING_CHANNEL_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include "small/include/small/ibuf.h"
#include "small/include/small/obuf.h"
#include "small/include/small/small.h"
#include "small/include/small/rlist.h"
#include "binding_transport.h"
#include "binding_controller.h"
#include <stdio.h>

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_channel_configuration
  {
    size_t buffers_count;
    uint32_t ring_size;
    uint32_t buffer_shift;
  } transport_channel_configuration_t;

  typedef struct transport_channel
  {
    struct io_uring ring;

    transport_t *transport;
    transport_controller_t *controller;

    Dart_Port read_port;
    Dart_Port write_port;

    void *context;

    bool active;

    uint32_t id;

    struct rlist balancer_link;
  } transport_channel_t;

  typedef struct transport_payload
  {
    int fd;
    void *data;
    size_t size;
  } transport_payload_t;

  transport_channel_t *transport_initialize_channel(transport_t *transport,
                                                    transport_controller_t *controller,
                                                    transport_channel_configuration_t *configuration,
                                                    Dart_Port read_port,
                                                    Dart_Port write_port);
  int transport_channel_loop(va_list input);

  void transport_close_channel(transport_channel_t *channel);

  void transport_channel_accept(struct transport_channel *channel, int fd);
  int32_t transport_channel_send(transport_channel_t *channel, void *data, size_t size, int fd);

  void transport_channel_free_payload(transport_channel_t *channel, transport_payload_t *payload);
#if defined(__cplusplus)
}
#endif

#endif
