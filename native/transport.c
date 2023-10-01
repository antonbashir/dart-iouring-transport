#include "transport.h"
#include <arpa/inet.h>
#include <errno.h>
#include <liburing.h>
#include <netinet/in.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>
#include "dart/dart_api.h"
#include "transport_constants.h"
#include "transport_server.h"

void transport_cqe_advance(struct io_uring* ring, int count)
{
    io_uring_cq_advance(ring, count);
}

void transport_close_descriptor(int fd)
{
    shutdown(fd, SHUT_RDWR);
    close(fd);
}
