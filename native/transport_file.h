#ifndef TRANSPORT_FILE_H_INCLUDED
#define TRANSPORT_FILE_H_INCLUDED
#include <stdbool.h>

#if defined(__cplusplus)
extern "C"
{
#endif
    int transport_file_open(const char* path, int mode, bool truncate, bool create);
#if defined(__cplusplus)
}
#endif

#endif
