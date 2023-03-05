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
#include <stdio.h>
#include "dart/dart_api_dl.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_channel_configuration
  {
    uint32_t buffers_count;
    uint32_t buffer_size;
  } transport_channel_configuration_t;

  typedef struct transport_channel
  {
    void *context;
    uint32_t buffer_size;
    uint32_t buffers_count;
  } transport_channel_t;

  typedef struct transport_message
  {
    int fd;
    int buffer_id;
    size_t size;
  } transport_message_t;

  transport_channel_t *transport_initialize_channel(transport_channel_configuration_t *configuration);

  transport_channel_t *transport_channel_share(transport_channel_t *source, struct io_uring *ring);

  int transport_channel_write(struct transport_channel *channel, int fd, int buffer_id);
  int transport_channel_read(struct transport_channel *channel, int fd, int buffer_id);

  void transport_close_channel(transport_channel_t *channel);

  void transport_channel_handle_write(struct transport_channel *channel, struct io_uring_cqe *cqe, int buffer_id);
  void transport_channel_handle_read(struct transport_channel *channel, struct io_uring_cqe *cqe, int buffer_id);

  struct iovec *transport_channel_get_buffer(transport_channel_t *channel, int buffer_id);
  int transport_channel_get_buffer_by_fd(transport_channel_t *channel, int fd);
  int transport_channel_allocate_buffer(transport_channel_t *channel);
  void transport_channel_free_buffer(transport_channel_t *channel, int buffer_d);
#if defined(__cplusplus)
}
#endif

#endif
