#include "binding_transport.h"
#include <liburing.h>
#include "stdlib.h"

void test()
{
  struct io_uring *ring = malloc(sizeof(struct io_uring));
  if (!ring)
  {
    return;
  }

  int32_t ret = io_uring_queue_init(128, ring, 0);
  if (ret < 0)
  {
    return;
  }

  printf("ring: %d\n", io_uring_sq_space_left(ring));
}