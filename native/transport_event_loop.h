#ifndef TRANSPORT_EVENT_LOOP_H_INCLUDED
#define TRANSPORT_EVENT_LOOP_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include <stdio.h>
#include "dart/dart_api.h"
#include "transport_channel.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_event_loop_configuration
  {
    uint32_t ring_size;
    uint32_t ring_flags;
    int32_t client_max_connections;
    uint32_t client_receive_buffer_size;
    uint32_t client_send_buffer_size;
  } transport_event_loop_configuration_t;

  typedef struct transport_event_loop
  {
    struct io_uring *ring;
    int32_t client_max_connections;
    uint32_t client_receive_buffer_size;
    uint32_t client_send_buffer_size;
    Dart_Port callback_send_port;
    transport_channel_t *channel;
  } transport_event_loop_t;

  transport_event_loop_t *transport_event_loop_initialize(transport_event_loop_configuration_t *configuration, Dart_Port callback_send_port);
  
  void transport_event_loop_start(transport_event_loop_t *loop);

  void transport_event_loop_stop(transport_event_loop_t *loop);

  int32_t transport_event_loop_connect(transport_event_loop_t *loop, const char *ip, int port, Dart_Handle callback);

  int32_t transport_event_loop_open(transport_event_loop_t *loop, const char *path, Dart_Handle callback);

  int32_t transport_event_loop_read(transport_event_loop_t *loop, int fd, int buffer_id, Dart_Handle callback);

  int32_t transport_event_loop_write(transport_event_loop_t *loop, int fd, int buffer_id, Dart_Handle callback);
#if defined(__cplusplus)
}
#endif

#endif
