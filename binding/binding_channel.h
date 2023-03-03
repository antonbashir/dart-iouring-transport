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
#include <stdio.h>
#include "dart/dart_api_dl.h"

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
    transport_t *transport;

    Dart_Port read_port;
    Dart_Port write_port;
    Dart_Port accept_port;

    void *context;

    bool active;

    struct rlist balancer_link;
  } transport_channel_t;

  typedef struct transport_message
  {
    int fd;
    int buffer_id;
    size_t size;
  } transport_message_t;

  transport_channel_t *transport_initialize_channel(transport_t *transport,
                                                    transport_channel_configuration_t *configuration,
                                                    Dart_Port accept_port,
                                                    Dart_Port read_port,
                                                    Dart_Port write_port);

  void transport_channel_register(struct transport_channel *channel, struct io_uring *ring);

  int transport_channel_write(struct transport_channel *channel, int fd, int buffer_id);
  int transport_channel_read(struct transport_channel *channel, int fd, int buffer_id);

  void transport_close_channel(transport_channel_t *channel);

  void transport_channel_handle_accept(struct transport_channel *channel, int fd);
  void transport_channel_handle_write(struct transport_channel *channel, struct io_uring_cqe *cqe);
  void transport_channel_handle_read(struct transport_channel *channel, struct io_uring_cqe *cqe);

  struct iovec *transport_channel_use_write_buffer(transport_channel_t *channel, int buffer_id);
  struct iovec *transport_channel_use_read_buffer(transport_channel_t *channel, int buffer_id);

  int transport_channel_select_write_buffer(transport_channel_t *channel);
  int transport_channel_select_read_buffer(transport_channel_t *channel);

  void transport_channel_free_buffer(transport_channel_t *channel, int buffer_d);

  int transport_channel_get_buffer_by_fd(transport_channel_t *channel, int fd);
#if defined(__cplusplus)
}
#endif

#endif
