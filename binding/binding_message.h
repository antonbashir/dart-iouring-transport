#ifndef BINDING_MESSAGE_H
#define BINDING_MESSAGE_H

#include "fiber_channel.h"

#if defined(__cplusplus)
extern "C"
{
#endif
  typedef enum transport_payload_type
  {
    TRANSPORT_PAYLOAD_READ = 1 << 0,
    TRANSPORT_PAYLOAD_WRITE = 2 << 0,
    TRANSPORT_PAYLOAD_ACCEPT = 3 << 0,
    TRANSPORT_PAYLOAD_CONNECT = 4 << 0,
    TRANSPORT_PAYLOAD_max
  } transport_payload_type_t;

  static int TRANSPORT_PAYLOAD_ALL_FLAGS = TRANSPORT_PAYLOAD_READ | TRANSPORT_PAYLOAD_WRITE | TRANSPORT_PAYLOAD_ACCEPT | TRANSPORT_PAYLOAD_CONNECT;

  struct transport_message
  {
    void *data;
    struct fiber_channel *channel;
  };

#if defined(__cplusplus)
}
#endif

#endif