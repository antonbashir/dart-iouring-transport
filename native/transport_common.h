#ifndef TRANSPORT_COMMON_H
#define TRANSPORT_COMMON_H

#if defined(__cplusplus)
extern "C"
{
#endif

#include <liburing.h>
#include "trivia/util.h"
#include "transport_logger.h"
#include "pthread.h"

  static inline struct io_uring_sqe *provide_sqe(struct io_uring *ring)
  {
    struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
    while (unlikely(sqe == NULL))
    {
      io_uring_submit_and_wait(ring, 1);
      sqe = io_uring_get_sqe(ring);
    }
    return sqe;
  };

#if defined(__cplusplus)
}
#endif

#endif
