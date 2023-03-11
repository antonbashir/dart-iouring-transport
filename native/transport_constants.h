#ifndef TRANSPORT_CONSTANTS_H
#define TRANSPORT_CONSTANTS_H

#include <stdint.h>

#if defined(__cplusplus)
extern "C"
{
#endif

#define TRANSPORT_EVENT_READ ((uint64_t)1 << (64 - 1 - 0))
#define TRANSPORT_EVENT_WRITE ((uint64_t)1 << (64 - 1 - 1))
#define TRANSPORT_EVENT_ACCEPT ((uint64_t)1 << (64 - 1 - 2))
#define TRANSPORT_EVENT_CONNECT ((uint64_t)1 << (64 - 1 - 3))
#define TRANSPORT_EVENT_CLOSE ((uint64_t)1 << (64 - 1 - 4))

#define TRANSPORT_NATIVE_LOG_BUFFER 2048

  static uint64_t TRANSPORT_EVENT_ALL_FLAGS = TRANSPORT_EVENT_READ | TRANSPORT_EVENT_WRITE | TRANSPORT_EVENT_ACCEPT | TRANSPORT_EVENT_CONNECT | TRANSPORT_EVENT_CLOSE;

#if defined(__cplusplus)
}
#endif

#endif