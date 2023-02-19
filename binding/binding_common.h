#ifndef BINDING_COMMON_H
#define BINDING_COMMON_H

#if defined(__cplusplus)
extern "C"
{
#endif

#include <liburing.h>
#include "trivia/util.h"
#include "dart/dart_api_dl.h"
#include "fiber.h"
#include "binding_logger.h"

  static inline struct io_uring_sqe *provide_sqe(struct io_uring *ring)
  {
    struct io_uring_sqe *sqe = io_uring_get_sqe(ring);
    while (unlikely(sqe == NULL))
    {
      io_uring_submit(ring);
      fiber_sleep(0);
      sqe = io_uring_get_sqe(ring);
    }
    return sqe;
  };

  static inline void dart_post_pointer(void *pointer, Dart_Port port)
  {
    Dart_CObject dart_object;
    dart_object.type = Dart_CObject_kInt64;
    dart_object.value.as_int64 = (int64_t)pointer;
    Dart_PostCObject(port, &dart_object);
  };

#if defined(__cplusplus)
}
#endif

#endif
