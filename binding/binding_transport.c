#include "binding_transport.h"
#include <liburing.h>
#include "stdio.h"

void test()
{
  struct io_uring ring;
  io_uring_queue_init(10, &ring, 0);
  printf("ring: %d\n", ring.ring_fd);
}