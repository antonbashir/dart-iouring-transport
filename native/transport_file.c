#include "transport_file.h"
#include "transport_constants.h"
#include <stdio.h>
#include <stdlib.h>
#include <liburing.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <stdint.h>

int transport_file_open(const char *path, int mode, bool truncate, bool create)
{
  int options = 0;
  if (mode == TRANSPORT_READ_ONLY)
  {
    options |= O_RDONLY;
  }
  if (mode == TRANSPORT_WRITE_ONLY)
  {
    options |= O_WRONLY;
  }
  if (mode == TRANSPORT_READ_WRITE)
  {
    options |= O_RDWR;
  }
  if (mode == TRANSPORT_WRITE_ONLY_APPEND)
  {
    options |= O_WRONLY | O_APPEND;
  }
  if (mode == TRANSPORT_READ_WRITE_APPEND)
  {
    options |= O_RDWR | O_APPEND;
  }
  if (truncate)
  {
    options |= O_TRUNC;
  }
  if (create)
  {
    options |= O_CREAT;
  }
  return open(path, options, 0666);
}