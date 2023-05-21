#ifndef TRANSPORT_H_INCLUDED
#define TRANSPORT_H_INCLUDED

#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>
#include "transport_server.h"
#include "transport_worker.h"
#include "transport_client.h"
#include "dart/dart_api.h"

#if defined(__cplusplus)
extern "C"
{
#endif
  struct io_uring_cqe **transport_allocate_cqes(uint32_t cqe_count);

  void transport_cqe_advance(struct io_uring *ring, int count);

  void transport_close_descritor(int fd);

  void transport_notify_idle(int64_t deadline);
#if defined(__cplusplus)
}
#endif

#endif
