#ifndef TRANSPORT_COLLECTIONS_H
#define TRANSPORT_COLLECTIONS_H

#include <stdint.h>

#if defined(__cplusplus)
extern "C"
{
#endif

#if !MH_SOURCE
#define MH_UNDEF
#endif

#define mh_name _i32
#define mh_key_t int32_t
  struct mh_i32_node_t
  {
    mh_key_t key;
    int64_t value;
  };

#define mh_node_t struct mh_i32_node_t
#define mh_arg_t int32_t
#define mh_hash(a, arg) (a->key)
#define mh_hash_key(a, arg) (a)
#define mh_cmp(a, b, arg) ((a->key) != (b->key))
#define mh_cmp_key(a, b, arg) ((a) != (b->key))
#include "salad/mhash.h"
#include "salad/fifo.h"

#if defined(__cplusplus)
}
#endif

#endif
