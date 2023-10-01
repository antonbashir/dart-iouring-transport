#ifndef TRANSPORT_H_INCLUDED
#define TRANSPORT_H_INCLUDED

#include <liburing.h>
#include <netinet/in.h>
#include <stdbool.h>
#include <stdint.h>
#include "dart/dart_api.h"
#include "transport_client.h"
#include "transport_server.h"
#include "transport_worker.h"

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
