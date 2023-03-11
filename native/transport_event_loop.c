#include <stdio.h>
#include <stdlib.h>
#include "transport_event_loop.h"
#include "transport_common.h"
#include "transport_constants.h"
#include "transport_socket.h"
#include "transport_file.h"
#include "transport_channel.h"
#include "dart/dart_native_api.h"

transport_event_loop_t *transport_event_loop_initialize(transport_event_loop_configuration_t *configuration, Dart_Port callback_send_port)
{
  transport_event_loop_t *loop = malloc(sizeof(transport_event_loop_t));
  struct io_uring *ring = malloc(sizeof(struct io_uring));
  int32_t status = io_uring_queue_init(configuration->ring_size, ring, configuration->ring_flags);
  loop->result_field = Dart_NewStringFromCString("result");
  if (status)
  {
    transport_error("[loop]: io_urig init error = %d", status);
    free(ring);
    free(loop);
    return NULL;
  }
  loop->ring = ring;
  return loop;
}

void transport_event_loop_start(transport_event_loop_t *loop)
{

  struct io_uring *ring = loop->ring;
  Dart_Port callback_send_port = loop->callback_send_port;
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
        io_uring_cqe_seen(ring, cqe);
        continue;
      }

      if (cqe->res == 0)
      {
        io_uring_cqe_seen(ring, cqe);
        continue;
      }

      Dart_PersistentHandle persistent_handle = (Dart_PersistentHandle)cqe->user_data;
      Dart_Handle handle = Dart_HandleFromPersistent(persistent_handle);
      Dart_SetField(handle, loop->result_field, Dart_NewInteger(cqe->res));
      Dart_CObject dart_object;
      dart_object.type = Dart_CObject_kInt64;
      dart_object.value.as_int64 = (int64_t)(handle);
      Dart_PostCObject(callback_send_port, &dart_object);
      Dart_DeletePersistentHandle(persistent_handle);
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

int32_t transport_event_loop_connect(transport_event_loop_t *loop, const char *ip, int port, Dart_Handle callback)
{
  struct io_uring_sqe *sqe = provide_sqe(loop->ring);
  struct sockaddr_in address;
  socklen_t address_length;
  memset(&address, 0, sizeof(address));
  address.sin_addr.s_addr = inet_addr(ip);
  address.sin_port = htons(port);
  address.sin_family = AF_INET;
  address_length = sizeof(address);
  int fd = transport_socket_create(loop->client_max_connections, loop->client_receive_buffer_size, loop->client_send_buffer_size);
  io_uring_prep_connect(sqe, fd, (struct sockaddr *)&address, &address_length);
  io_uring_sqe_set_data64(sqe, (intptr_t)Dart_NewPersistentHandle(callback));
  return io_uring_submit(loop->ring);
}

int32_t transport_event_loop_open(transport_event_loop_t *loop, const char *file, Dart_Handle callback)
{
  Dart_SetField(callback, loop->result_field, Dart_NewInteger(transport_file_open(file)));
  Dart_CObject dart_object;
  dart_object.type = Dart_CObject_kInt64;
  dart_object.value.as_int64 = (int64_t)(callback);
  return Dart_PostCObject(loop->callback_send_port, &dart_object) ? 0 : -1;
}

int32_t transport_event_loop_read(transport_event_loop_t *loop, int fd, int buffer_id, Dart_Handle callback)
{
  transport_channel_read_custom_data(loop->channel, fd, buffer_id, Dart_NewPersistentHandle(callback));
}

int32_t transport_event_loop_write(transport_event_loop_t *loop, int fd, int buffer_id, Dart_Handle callback)
{
  transport_channel_write_custom_data(loop->channel, fd, buffer_id, Dart_NewPersistentHandle(callback));
}
