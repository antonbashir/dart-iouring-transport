#include "binding_file.h"
#include <stdio.h>
#include <stdlib.h>
#include <liburing.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <stdint.h>

int32_t transport_file_open(const char *path)
{
  int32_t fd = open(path, O_RDWR | O_TRUNC);
  if (fd < 0)
  {
    fd = open(path, O_CREAT | O_RDWR, 0666);
    if (fd < 0)
    {
      return -1;
    }
  }
  return (int32_t)fd;
}