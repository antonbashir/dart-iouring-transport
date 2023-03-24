#ifndef TRANSPORT_CONSTANTS_H
#define TRANSPORT_CONSTANTS_H

#include <stdint.h>

#if defined(__cplusplus)
extern "C"
{
#endif

#define TRANSPORT_EVENT_CLOSE ((uint16_t)1 << 1)
#define TRANSPORT_EVENT_READ ((uint16_t)1 << 2)
#define TRANSPORT_EVENT_WRITE ((uint16_t)1 << 3)
#define TRANSPORT_EVENT_ACCEPT ((uint16_t)1 << 4)
#define TRANSPORT_EVENT_CONNECT ((uint16_t)1 << 5)
#define TRANSPORT_EVENT_READ_CALLBACK ((uint16_t)1 << 6)
#define TRANSPORT_EVENT_WRITE_CALLBACK ((uint16_t)1 << 7)
#define TRANSPORT_EVENT_INTERNAL ((uint16_t)1 << 8)
#define TRANSPORT_EVENT_EXTERNAL ((uint16_t)1 << 9)

#if defined(__cplusplus)
}
#endif

#endif