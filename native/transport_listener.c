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
#include "transport_acceptor.h"
#include "transport_client.h"
#include "transport.h"

transport_listener_t *transport_listener_initialize(transport_listener_configuration_t *configuration)
{
  transport_listener_t *listener = malloc(sizeof(transport_listener_t));
  if (!listener)
  {
    return NULL;
  }

  listener->ready_workers = malloc(sizeof(int) * configuration->workers_count);
  for (size_t workerIndex = 0; workerIndex < configuration->workers_count; workerIndex++)
  {
    listener->ready_workers[workerIndex] = 0;
  }

  struct io_uring *ring = malloc(sizeof(struct io_uring));
  int32_t status = io_uring_queue_init(configuration->ring_size, ring, configuration->ring_flags);
  if (status)
  {
    free(ring);
    free(listener);
    return NULL;
  }

  listener->ring = ring;
  return listener;
}

void transport_listener_reap(transport_listener_t *listener, struct io_uring_cqe **cqes)
{
  int32_t cqeCount = 0;
  uint32_t ready_workers_count = 0;
  if (likely(cqeCount = transport_wait(listener->ring_size, cqes, listener->ring) != -1))
  {
    for (size_t cqeIndex = 0; cqeIndex < cqeCount; cqeIndex++)
    {
      listener->ready_workers[cqes[cqeIndex]->res] = 1;
      if (++ready_workers_count == listener->workers_count)
      {
        io_uring_cq_advance(listener->ring, cqeCount);
        return;
      }
    }
    io_uring_cq_advance(listener->ring, cqeCount);
  }
}

void transport_listener_destroy(transport_listener_t *listener)
{
  io_uring_unregister_buffers(listener->ring);
  io_uring_queue_exit(listener->ring);
  free(listener->ring);
  free(listener);
}