#ifndef BINDING_MESSAGE_H
#define BINDING_MESSAGE_H

#include "fiber_channel.h"

#if defined(__cplusplus)
extern "C"
{
#endif

  struct transport_message
  {
    void *data;
    struct fiber_channel *channel;
  };

#if defined(__cplusplus)
}
#endif

#endif