#ifndef TRANSPORT_CONSTANTS_H
#define TRANSPORT_CONSTANTS_H

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
    int32_t value;
  };

#define mh_node_t struct mh_i32_node_t
#define mh_arg_t int32_t
#define mh_hash(a, arg) (a->key)
#define mh_hash_key(a, arg) (a)
#define mh_cmp(a, b, arg) ((a->key) != (b->key))
#define mh_cmp_key(a, b, arg) ((a) != (b->key))
#include "salad/mhash.h"

#define TRANSPORT_EVENT_CLOSE ((uint64_t)1 << (64 - 1))
#define TRANSPORT_EVENT_READ ((uint64_t)1 << (64 - 2))
#define TRANSPORT_EVENT_WRITE ((uint64_t)1 << (64 - 3))
#define TRANSPORT_EVENT_ACCEPT ((uint64_t)1 << (64 - 4))
#define TRANSPORT_EVENT_CONNECT ((uint64_t)1 << (64 - 5))
#define TRANSPORT_EVENT_READ_CALLBACK ((uint64_t)1 << (64 - 6))
#define TRANSPORT_EVENT_WRITE_CALLBACK ((uint64_t)1 << (64 - 7))
#define TRANSPORT_EVENT_MESSAGE ((uint64_t)1 << (64 - 8))

#define TRANSPORT_EVENT_MAX 8

  static uint64_t TRANSPORT_EVENT_ALL_FLAGS = TRANSPORT_EVENT_READ | TRANSPORT_EVENT_WRITE | TRANSPORT_EVENT_ACCEPT | TRANSPORT_EVENT_CONNECT | TRANSPORT_EVENT_CLOSE | TRANSPORT_EVENT_READ_CALLBACK | TRANSPORT_EVENT_WRITE_CALLBACK;

#if defined(__cplusplus)
}
#endif

#endif