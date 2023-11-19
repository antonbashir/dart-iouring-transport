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

#define mh_name _events
#define mh_key_t uint64_t
  struct mh_events_node_t
  {
    mh_key_t data;
    int64_t timeout;
    uint64_t timestamp;
    int fd;
  };

#define mh_node_t struct mh_events_node_t
#define mh_arg_t uint64_t
#define mh_hash(a, arg) (a->data)
#define mh_hash_key(a, arg) (a)
#define mh_cmp(a, b, arg) ((a->data) != (b->data))
#define mh_cmp_key(a, b, arg) ((a) != (b->data))
#include "collections/mhash.h"
#undef mh_node_t
#undef mh_arg_t
#undef mh_hash
#undef mh_hash_key
#undef mh_cmp
#undef mh_cmp_key

#if defined(__cplusplus)
}
#endif

#endif
