#ifndef TRANSPORT_CHANNEL_H_INCLUDED
#define TRANSPORT_CHANNEL_H_INCLUDED
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

#define LIGHT_NAME _buffer_by_fd
#define LIGHT_DATA_TYPE int
#define LIGHT_KEY_TYPE int
#define LIGHT_CMP_ARG_TYPE int
#define LIGHT_EQUAL(a, b, ignore) a == b
#define LIGHT_EQUAL_KEY(a, b, ignore) a == b

#include "salad/light.h"

#undef LIGHT_NAME
#undef LIGHT_DATA_TYPE
#undef LIGHT_KEY_TYPE
#undef LIGHT_CMP_ARG_TYPE
#undef LIGHT_EQUAL
#undef LIGHT_EQUAL_KEY

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
    int *buffers_state;
    struct light_buffer_by_fd_core buffer_by_fd;
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

  transport_channel_t *transport_channel_for_ring(transport_channel_configuration_t *configuration, struct io_uring *ring);
  void transport_channel_for_ring_close(transport_channel_t *channel);

  int transport_channel_write(struct transport_channel *channel, int fd, int buffer_id);
  int transport_channel_read(struct transport_channel *channel, int fd, int buffer_id);

  int transport_channel_write_custom_data(struct transport_channel *channel, int fd, int buffer_id, uint64_t offset, int64_t user_data);
  int transport_channel_read_custom_data(struct transport_channel *channel, int fd, int buffer_id, uint64_t offset, int64_t user_data);

  int transport_channel_handle_write(struct transport_channel *channel, int fd, size_t size);
  int transport_channel_handle_read(struct transport_channel *channel, int fd, size_t size);

  int transport_channel_allocate_buffer(transport_channel_t *channel);

  void transport_channel_free_buffer_by_id(transport_channel_t *channel, int id);
  void transport_channel_free_buffer_by_fd(transport_channel_t *channel, int fd);

  void transport_channel_complete_write_by_fd(transport_channel_t *channel, int fd);
  void transport_channel_complete_write_by_buffer_id(transport_channel_t *channel, int fd, int id);
#if defined(__cplusplus)
}
#endif

#endif
