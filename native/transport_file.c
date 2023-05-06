#include "transport_file.h"
#include <stdio.h>
#include <stdlib.h>
#include <liburing.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <stdint.h>

int transport_file_open(const char *path, int options, int mode)
{
  return open(path, options | O_NONBLOCK, mode);
}