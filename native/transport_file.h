#ifndef TRANSPORT_FILE_H_INCLUDED
#define TRANSPORT_FILE_H_INCLUDED
#include <stdint.h>

#if defined(__cplusplus)
extern "C"
{
#endif
  int transport_file_open(const char* path, int options, int mode);
#if defined(__cplusplus)
}
#endif

#endif
