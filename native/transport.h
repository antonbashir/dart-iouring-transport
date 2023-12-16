#ifndef TRANSPORT_H_INCLUDED
#define TRANSPORT_H_INCLUDED

#include <liburing.h>
#include <netinet/in.h>
#include <stdbool.h>

#if defined(__cplusplus)
extern "C"
{
#endif
    void transport_cqe_advance(struct io_uring* ring, int count);

    void transport_close_descriptor(int fd);
#if defined(__cplusplus)
}
#endif

#endif
