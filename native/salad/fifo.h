#ifndef TARANTOOL_LIB_SALAD_FIFO_H_INCLUDED
#define TARANTOOL_LIB_SALAD_FIFO_H_INCLUDED
/*
 * Copyright 2010-2016, Tarantool AUTHORS, please see AUTHORS file.
 *
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 *
 * 1. Redistributions of source code must retain the above
 *    copyright notice, this list of conditions and the
 *    following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY <COPYRIGHT HOLDER> ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * <COPYRIGHT HOLDER> OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 * THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include "../trivia/util.h"

#define FIFO_WATERMARK (512 * sizeof(void *))

/** A simple FIFO made using a ring buffer */

struct fifo
{
  int32_t *buf;
  size_t bottom; /* advanced by batch free */
  size_t top;
  size_t size; /* total buffer size */
};

static inline int
fifo_create(struct fifo *q, size_t size)
{
  q->size = size;
  q->bottom = 0;
  q->top = 0;
  q->buf = (int32_t *)malloc(size);
  return (q->buf == NULL ? -1 : 0);
}

static inline void
fifo_destroy(struct fifo *q)
{
  if (q->buf)
  {
    free(q->buf);
    q->buf = NULL;
  }
}

static inline int
fifo_size(struct fifo *q)
{
  return (q->top - q->bottom) / sizeof(void *);
}

static inline int
fifo_push(struct fifo *q, int32_t value)
{
  /* reduce memory allocation and memmove
   * effect by reusing free pointers buffer space only after the
   * watermark frees reached. */
  if (unlikely(q->bottom >= FIFO_WATERMARK))
  {
    memmove(q->buf, q->buf + q->bottom, q->bottom);
    q->top -= q->bottom;
    q->bottom = 0;
  }
  if (unlikely((q->top + sizeof(int32_t)) > q->size))
  {
    size_t newsize = q->size * 2;
    int32_t *ptr = (int32_t *)realloc((void *)q->buf, newsize);
    if (unlikely(ptr == NULL))
      return -1;
    q->buf = ptr;
    q->size = newsize;
  }
  *(q->buf + q->top) = value;
  q->top += sizeof(int32_t);
  return 0;
}

static inline int32_t
fifo_pop(struct fifo *q)
{
  if (unlikely(q->bottom == q->top))
    return -1;
  int32_t ret = *(q->buf + q->bottom);
  q->bottom += sizeof(int32_t);
  return ret;
}

#undef FIFO_WATERMARK

#endif /* TARANTOOL_LIB_SALAD_FIFO_H_INCLUDED */
