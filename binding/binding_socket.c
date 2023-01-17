#include "binding_socket.h"
#include <stdio.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <liburing.h>
#include <string.h>
#include <errno.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdint.h>

int32_t transport_socket_create() {
    int32_t val = 1;

    int32_t fd = socket(PF_INET, SOCK_STREAM, 0);
    if (fd == -1) {
        return -1;
    }

    int32_t result = setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &val, sizeof(int));
    if (result < 0) {
        return -1;
    }

    result = setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &val, sizeof(val));
    if (result == -1) {
        return -1;
    }

    return (uint32_t) fd;
}

int32_t transport_socket_bind(int32_t server_socket_fd, const char* ip, int32_t port, int32_t backlog) {
    struct sockaddr_in server_address;
    memset(&server_address, 0, sizeof(server_address));
    server_address.sin_family = AF_INET;
    server_address.sin_port = htons(port);
    server_address.sin_addr.s_addr = inet_addr(ip);

    int32_t result = bind(server_socket_fd, (const struct sockaddr *) &server_address, sizeof(server_address));
    if (result < 0) {
        return -1;
    }

    result = listen(server_socket_fd, backlog);
    if (result < 0) {
        return -1;
    }

    return result;
}
