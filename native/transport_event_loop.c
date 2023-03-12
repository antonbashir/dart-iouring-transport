#include <stdio.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <liburing.h>
#include <string.h>
#include <errno.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdint.h>
#include <sys/time.h>
#include "transport_event_loop.h"
#include "transport_common.h"
#include "transport_constants.h"
#include "transport_socket.h"
#include "transport_file.h"
#include "transport_channel.h"
#include "dart/dart_api.h"
#include "dart/dart_native_api.h"

transport_event_loop_t *transport_event_loop_initialize(transport_event_loop_configuration_t *loop_configuration, transport_channel_configuration_t *channel_configuration)
{
  transport_event_loop_t *loop = malloc(sizeof(transport_event_loop_t));
  loop->client_max_connections = loop_configuration->client_max_connections;
  loop->client_receive_buffer_size = loop_configuration->client_receive_buffer_size;
  loop->client_send_buffer_size = loop_configuration->client_send_buffer_size;
  struct io_uring *ring = malloc(sizeof(struct io_uring));
  int32_t status = io_uring_queue_init(loop_configuration->ring_size, ring, loop_configuration->ring_flags);
  if (status)
  {
    transport_error("[loop]: io_urig init error = %d", status);
    free(ring);
    free(loop);
    return NULL;
  }
  loop->ring = ring;
  loop->channel = transport_channel_for_ring(channel_configuration, ring);
  loop->events_cache = malloc(sizeof(transport_event_t) * loop->channel->buffers_count);
  for (size_t event_index = 0; event_index < loop->channel->buffers_count; event_index++)
  {
    loop->events_cache[event_index].socket_fd = -1;
    loop->events_cache[event_index].free = false;
  }

  transport_info("[loop]: initialized");
  return loop;
}

void transport_event_loop_start(transport_event_loop_t *loop, Dart_Port callback_port)
{
  struct io_uring *ring = loop->ring;
  struct io_uring_cqe *cqe;
  unsigned head;
  int count = 0;
  while (true)
  {
    if (likely(io_uring_wait_cqe(ring, &cqe) == 0))
    {
      if (unlikely(cqe->user_data & TRANSPORT_EVENT_CLOSE))
      {
        io_uring_cqe_seen(ring, cqe);
        break;
      }

      if (unlikely(cqe->res < 0))
      {
        transport_error("[loop]: cqe result error = %d", cqe->res);
        io_uring_cqe_seen(ring, cqe);
        continue;
      }

      transport_event_t *event = (transport_event_t *)cqe->user_data;
      event->result = cqe->res;
      Dart_CObject dart_object;
      dart_object.type = Dart_CObject_kInt64;
      dart_object.value.as_int64 = (int64_t)cqe->user_data;
      Dart_PostCObject(callback_port, &dart_object);
      io_uring_cqe_seen(ring, cqe);
    }
  }
  transport_event_loop_stop(loop);
}

void transport_event_loop_stop(transport_event_loop_t *loop)
{
  struct io_uring_sqe *sqe = provide_sqe(loop->ring);
  io_uring_prep_nop(sqe);
  io_uring_sqe_set_data64(sqe, (uint64_t)TRANSPORT_EVENT_CLOSE);
  io_uring_submit(loop->ring);
  transport_info("[loop]: stop");
}

int transport_event_loop_connect(transport_event_loop_t *loop, const char *ip, int port, Dart_Handle callback)
{
  struct io_uring_sqe *sqe = provide_sqe(loop->ring);
  struct sockaddr_in *address = malloc(sizeof(struct sockaddr_in));
  memset(address, 0, sizeof(*address));
  address->sin_addr.s_addr = inet_addr(ip);
  address->sin_port = htons(port);
  address->sin_family = AF_INET;
  int fd = transport_socket_create(loop->client_max_connections, loop->client_receive_buffer_size, loop->client_send_buffer_size);
  transport_event_t *event = malloc(sizeof(transport_event_t));
  event->callback = (Dart_Handle *)Dart_NewPersistentHandle(callback);
  event->free = true;
  event->socket_fd = fd;
  io_uring_prep_connect(sqe, fd, (struct sockaddr *)address, sizeof(*address));
  io_uring_sqe_set_data64(sqe, (int64_t)event);
  return io_uring_submit(loop->ring);
}

int transport_event_loop_read(transport_event_loop_t *loop, int fd, int buffer_id, uint64_t offset, Dart_Handle callback)
{
  transport_event_t *event = &loop->events_cache[buffer_id];
  event->callback = (Dart_Handle *)Dart_NewPersistentHandle(callback);
  transport_channel_read_custom_data(loop->channel, fd, buffer_id, offset, (int64_t)event);
}

int transport_event_loop_write(transport_event_loop_t *loop, int fd, int buffer_id, uint64_t offset, Dart_Handle callback)
{
  transport_event_t *event = &loop->events_cache[buffer_id];
  event->callback = (Dart_Handle *)Dart_NewPersistentHandle(callback);
  return transport_channel_write_custom_data(loop->channel, fd, buffer_id, offset, (int64_t)event);
}

Dart_Handle transport_get_handle_from_event(transport_event_t *event)
{
  return Dart_HandleFromPersistent((Dart_PersistentHandle)event->callback);
}

void transport_delete_handle_from_event(transport_event_t *event)
{
  Dart_DeletePersistentHandle((Dart_PersistentHandle)event->callback);
}