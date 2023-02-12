#ifndef BINDING_MESSAGE_H
#define BINDING_MESSAGE_H

#include "fiber_channel.h"

#if defined(__cplusplus)
extern "C"
{
#endif

#define TRANSPORT_PAYLOAD_READ ((uint64_t)1 << (64 - 1 - 0))
#define TRANSPORT_PAYLOAD_WRITE ((uint64_t)1 << (64 - 1 - 1))
#define TRANSPORT_PAYLOAD_ACCEPT ((uint64_t)1 << (64 - 1 - 2))
#define TRANSPORT_PAYLOAD_CONNECT ((uint64_t)1 << (64 - 1 - 3))

#define TRANSPORT_ACTION_ADD_CONNECTOR (1U << 0)
#define TRANSPORT_ACTION_ADD_ACCEPTOR (1U << 1)
#define TRANSPORT_ACTION_ADD_CHANNEL (1U << 2)
#define TRANSPORT_ACTION_SEND (1U << 3)

  static uint64_t TRANSPORT_PAYLOAD_ALL_FLAGS = TRANSPORT_PAYLOAD_READ | TRANSPORT_PAYLOAD_WRITE | TRANSPORT_PAYLOAD_ACCEPT | TRANSPORT_PAYLOAD_CONNECT;

  struct transport_message
  {
    void *data;
    struct fiber_channel *channel;
    int action;
  };

#if defined(__cplusplus)
}
#endif

#endif