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
#include "transport_common.h"
#include "transport_constants.h"
#include "transport_listener.h"
#include "transport_worker.h"
#include "transport_server.h"
#include "transport_client.h"
#include "transport.h"

int transport_listener_initialize(transport_listener_t *listener, transport_listener_configuration_t *configuration, uint8_t id)
{
  listener->id = id;
  listener->ready_workers = malloc(sizeof(int) * configuration->workers_count);
  listener->ring_size = configuration->ring_size;
  if (!listener->ready_workers)
  {
    return -ENOMEM;
  }

  for (size_t workerIndex = 0; workerIndex < configuration->workers_count; workerIndex++)
  {
    listener->ready_workers[workerIndex] = 0;
  }

  listener->ring = malloc(sizeof(struct io_uring));
  if (!listener->ring)
  {
    return -ENOMEM;
  }
  int32_t status = io_uring_queue_init(configuration->ring_size, listener->ring, configuration->ring_flags);
  if (status)
  {
    return status;
  }
  return 0;
}

static inline int transport_listener_wait(uint32_t cqe_count, struct io_uring_cqe **cqes, struct io_uring *ring)
{
  int count = 0;
  if (unlikely(!(count = io_uring_peek_batch_cqe(ring, &cqes[0], cqe_count))))
  {
    struct __kernel_timespec timeout = {
        .tv_nsec = 1000000,
        .tv_sec = 0,
    };

    if (likely(count = io_uring_wait_cqes(ring, &cqes[0], cqe_count, &timeout, 0) >= 0))
    {
     // printf("listener wait: %d\n", count);
      count = io_uring_peek_batch_cqe(ring, &cqes[0], cqe_count);
     // printf("listener batch: %d\n", count);
      return count;
    }
    return -1;
  }
  return count;
}

void transport_listener_close(transport_listener_t *listener)
{
  struct io_uring_sqe *sqe = transport_provide_sqe(listener->ring);
  io_uring_prep_msg_ring(sqe, listener->ring->ring_fd, -1, 0, 0);
  sqe->flags |= IOSQE_CQE_SKIP_SUCCESS;
  io_uring_submit(listener->ring);
}

bool transport_listener_reap(transport_listener_t *listener, struct io_uring_cqe **cqes)
{
  int32_t cqeCount = 0;
  if (likely(cqeCount = transport_listener_wait(listener->ring_size, cqes, listener->ring) != -1))
  {
    for (size_t cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++)
    {
      int result = cqes[cqeIndex]->res;
      if (unlikely(result == -1))
      {
        io_uring_cq_advance(listener->ring, cqeIndex + 1);
        return false;
      }
      listener->ready_workers[result] = 1;
    }
    io_uring_cq_advance(listener->ring, cqeCount);
  }
  return true;
}

void transport_listener_notify_idle(int64_t deadline)
{
  Dart_NotifyIdle(deadline);
}

void transport_listener_notify_detach()
{
  Dart_NotifyLowMemory();
}

void transport_listener_destroy(transport_listener_t *listener)
{
  io_uring_queue_exit(listener->ring);
  free(listener->ring);
  free(listener->ready_workers);
  free(listener);
}