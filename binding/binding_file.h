#ifndef BINDING_FILE_H_INCLUDED
#define BINDING_FILE_H_INCLUDED
#include <stdint.h>

#if defined(__cplusplus)
extern "C"
{
#endif
  int32_t transport_file_open(const char* path);
#if defined(__cplusplus)
}
#endif

#endif