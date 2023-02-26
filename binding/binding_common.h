#ifndef BINDING_COMMON_H
#define BINDING_COMMON_H

#if defined(__cplusplus)
extern "C"
{
#endif

#include <liburing.h>
#include "trivia/util.h"
#include "fiber.h"
#include "binding_logger.h"

#define NANOS_PER_SEC 1000000000LL

  static inline struct io_uring_sqe *provide_sqe(struct io_uring *ring)
  {
    struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
    while (unlikely(sqe == NULL))
    {
      io_uring_submit(ring);
      fiber_yield();
      sqe = io_uring_get_sqe(ring);
    }
    return sqe;
  };

#if defined(__cplusplus)
}
#endif

#endif
