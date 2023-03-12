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
  typedef struct transport_event
  {
    Dart_Handle *callback;
    int32_t result;
    int32_t socket_fd;
    bool free;
  } transport_event_t;

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
    transport_channel_t *channel;
    transport_event_t *events_cache;
  } transport_event_loop_t;

  transport_event_loop_t *transport_event_loop_initialize(transport_event_loop_configuration_t *loop_configuration, transport_channel_configuration_t *channel_configuration);

  void transport_event_loop_start(transport_event_loop_t *loop, Dart_Port callback_port);

  void transport_event_loop_stop(transport_event_loop_t *loop);

  int transport_event_loop_connect(transport_event_loop_t *loop, const char *ip, int port, Dart_Handle callback);

  int transport_event_loop_read(transport_event_loop_t *loop, int fd, int buffer_id, uint64_t offset, Dart_Handle callback);
  int transport_event_loop_write(transport_event_loop_t *loop, int fd, int buffer_id, uint64_t offset, Dart_Handle callback);

  Dart_Handle transport_get_handle_from_event(transport_event_t *event);

  void transport_delete_handle_from_event(transport_event_t *event);
#if defined(__cplusplus)
}
#endif

#endif
