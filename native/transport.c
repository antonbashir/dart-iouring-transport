#include "dart/dart_api.h"
#include <stdio.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <liburing.h>
#include <string.h>
#include <errno.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdint.h>
#include <pthread.h>
#include <sys/time.h>
#include "transport.h"
#include "transport_constants.h"
#include "transport_server.h"
#include "small/include/small/rlist.h"

void transport_notify_idle(int64_t deadline)
{
  Dart_NotifyIdle(deadline);
}

void transport_cqe_advance(struct io_uring *ring, int count)
{
  io_uring_cq_advance(ring, count);
}

struct io_uring_cqe **transport_allocate_cqes(uint32_t cqe_count)
{
  struct io_uring_cqe ** cqes = malloc(sizeof(struct io_uring_cqe) * cqe_count);
  memset(cqes, 0, sizeof(struct io_uring_cqe) * cqe_count);
  return cqes;
}

void transport_close_descritor(int fd)
{
  shutdown(fd, SHUT_RDWR);
  close(fd);
}
