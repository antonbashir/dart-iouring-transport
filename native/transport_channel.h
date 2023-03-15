#ifndef TRANSPORT_CHANNEL_H_INCLUDED
#define TRANSPORT_CHANNEL_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include <stdio.h>
#include "small/include/small/ibuf.h"
#include "small/include/small/obuf.h"
#include "small/include/small/small.h"
#include "small/include/small/rlist.h"
#include "dart/dart_api_dl.h"
#include "transport_constants.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef struct transport_channel_configuration
  {
    uint32_t buffers_count;
    uint32_t buffer_size;
    size_t ring_size;
    int ring_flags;
  } transport_channel_configuration_t;

  typedef struct transport_channel
  {
    struct io_uring *ring;
    struct iovec *buffers;
    uint32_t buffer_size;
    uint32_t buffers_count;
    int *used_buffers;
    int available_buffer_id;
    struct rlist channel_pool_link;
  } transport_channel_t;

  typedef struct transport_message
  {
    int fd;
    int buffer_id;
    size_t size;
  } transport_message_t;

  transport_channel_t *transport_channel_initialize(transport_channel_configuration_t *configuration);
  void transport_channel_close(transport_channel_t *channel);

  int transport_channel_write(struct transport_channel *channel, int fd, int buffer_id, int64_t offset, int64_t event);
  int transport_channel_read(struct transport_channel *channel, int fd, int buffer_id, int64_t offset, int64_t event);
  int transport_channel_connect(struct transport_channel *channel, int fd, const char *ip, int port);
  int transport_channel_message(struct transport_channel *fromChannel, struct transport_channel *toChannel, int64_t result, int64_t user_data);

  int transport_channel_allocate_buffer(transport_channel_t *channel);

  void transport_channel_free_buffer(transport_channel_t *channel, int id);
#if defined(__cplusplus)
}
#endif

#endif
