#ifndef BINDING_TRANSPORT_H_INCLUDED
#define BINDING_TRANSPORT_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include "small/include/small/ibuf.h"
#include "small/include/small/obuf.h"
#include "small/include/small/small.h"
#include "small/include/small/slab_cache.h"
#include "small/include/small/slab_arena.h"
#include "small/include/small/quota.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef enum transport_message_type
  {
    TRANSPORT_MESSAGE_READ,
    TRANSPORT_MESSAGE_WRITE,
    TRANSPORT_MESSAGE_ACCEPT,
    TRANSPORT_MESSAGE_CONNECT,
    TRANSPORT_MESSAGE_max
  } transport_message_type_t;

  typedef struct transport_configuration
  {
    uint32_t ring_size;
    uint32_t slab_size;
    size_t memory_quota;
    size_t buffer_initial_capacity;
    size_t buffer_limit;
    uint32_t slab_allocation_minimal_object_size;
    size_t slab_allocation_granularity;
    float slab_allocation_factor;
  } transport_configuration_t;

  typedef struct transport_message
  {
    int32_t fd;
    transport_message_type_t type;
    struct ibuf *read_buffer;
    struct obuf *write_buffer;
    int32_t size;
  } transport_message_t;

  typedef struct transport_accept_request
  {
    int32_t fd;
    transport_message_type_t type;
    struct sockaddr_in client_addres;
    socklen_t client_addres_length;
  } transport_accept_request_t;

  typedef struct transport_context
  {
    struct io_uring ring;

    struct slab_arena arena;
    struct slab_cache cache;
    struct small_alloc allocator;
    struct quota quota;

    struct ibuf read_buffers[2];
    struct ibuf *current_read_buffer;

    struct obuf write_buffers[2];
    struct obuf *current_write_buffer;

    size_t current_read_size;

    size_t buffer_initial_capacity;
    size_t buffer_limit;
  } transport_context_t;

  int32_t transport_submit_receive(transport_context_t *context, struct io_uring_cqe **cqes, uint32_t cqes_size, bool wait);
  void transport_mark_cqe(transport_context_t *context, transport_message_type_t type, struct io_uring_cqe *cqe);
  int32_t transport_queue_read(transport_context_t *context, int32_t fd, uint32_t size, uint64_t offset);
  int32_t transport_queue_write(transport_context_t *context, int32_t fd, void *buffer, uint32_t size, uint64_t offset);
  int32_t transport_queue_accept(transport_context_t *context, int32_t server_socket_fd);
  int32_t transport_queue_connect(transport_context_t *context, int32_t socket_fd, const char *ip, int32_t port);

  transport_context_t *transport_initialize(transport_configuration_t *configuration);
  void transport_close();

  void transport_close_descriptor(int32_t fd);

  void* transport_copy_write_buffer(transport_message_t* message);
  size_t transport_read_buffer_used(transport_context_t *context);

  void *transport_begin_read(transport_context_t *context, size_t size);
  void transport_complete_read(transport_context_t *context, transport_message_t *message);
  void *transport_begin_write(transport_context_t *context, size_t size);
  void transport_complete_write(transport_context_t *context, transport_message_t *message);

  struct io_uring_cqe **transport_allocate_cqes(transport_context_t *context, uint32_t count);
  void transport_free_cqes(transport_context_t *context, struct io_uring_cqe **cqes, uint32_t count);
#if defined(__cplusplus)
}
#endif

#endif
