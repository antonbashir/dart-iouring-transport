#ifndef BINDING_MESSAGE_H
#define BINDING_MESSAGE_H

#include "fiber_channel.h"

#if defined(__cplusplus)
extern "C"
{
#endif

#define TRANSPORT_PAYLOAD_READ (1U << 0)
#define TRANSPORT_PAYLOAD_WRITE (1U << 1)
#define TRANSPORT_PAYLOAD_ACCEPT (1U << 2)
#define TRANSPORT_PAYLOAD_CONNECT (1U << 3)

#define TRANSPORT_ACTION_ADD_CONNECTOR (1U << 0)
#define TRANSPORT_ACTION_ADD_ACCEPTOR (2U << 1)
#define TRANSPORT_ACTION_ADD_CHANNEL (3U << 2)
#define TRANSPORT_ACTION_SEND (4U << 3)

  static int TRANSPORT_PAYLOAD_ALL_FLAGS = TRANSPORT_PAYLOAD_READ | TRANSPORT_PAYLOAD_WRITE | TRANSPORT_PAYLOAD_ACCEPT | TRANSPORT_PAYLOAD_CONNECT;

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