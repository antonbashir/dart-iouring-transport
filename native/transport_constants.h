#ifndef TRANSPORT_CONSTANTS_H
#define TRANSPORT_CONSTANTS_H

#include <stdint.h>

#if defined(__cplusplus)
extern "C"
{
#endif

#define TRANSPORT_PAYLOAD_READ ((uint64_t)1 << (64 - 1 - 0))
#define TRANSPORT_PAYLOAD_WRITE ((uint64_t)1 << (64 - 1 - 1))
#define TRANSPORT_PAYLOAD_ACCEPT ((uint64_t)1 << (64 - 1 - 2))
#define TRANSPORT_PAYLOAD_CONNECT ((uint64_t)1 << (64 - 1 - 3))
#define TRANSPORT_PAYLOAD_ACTIVATE ((uint64_t)1 << (64 - 1 - 4))
#define TRANSPORT_PAYLOAD_CLOSE ((uint64_t)1 << (64 - 1 - 5))

#define TRANSPORT_NATIVE_LOG_BUFFER 2048

  static uint64_t TRANSPORT_PAYLOAD_ALL_FLAGS = TRANSPORT_PAYLOAD_READ | TRANSPORT_PAYLOAD_WRITE | TRANSPORT_PAYLOAD_ACCEPT | TRANSPORT_PAYLOAD_CONNECT | TRANSPORT_PAYLOAD_ACTIVATE | TRANSPORT_PAYLOAD_CLOSE;

#if defined(__cplusplus)
}
#endif

#endif