#include "transport.h"
#include <arpa/inet.h>
#include <liburing.h>
#include <netinet/in.h>
#include <pthread.h>
#include <sys/time.h>
#include <unistd.h>

void transport_cqe_advance(struct io_uring* ring, int count)
{
    io_uring_cq_advance(ring, count);
}

void transport_close_descriptor(int fd)
{
    shutdown(fd, SHUT_RDWR);
    close(fd);
}
