#ifndef BINDING_TRANSPORT_H_INCLUDED
#define BINDING_TRANSPORT_H_INCLUDED
#include <stdbool.h>
#include <netinet/in.h>
#include <stdint.h>
#include <liburing.h>

#if defined(__cplusplus)
extern "C"
{
#endif

  typedef enum transport_message_type
  {
    TRANSPORT_MESSAGE_READ,
    TRANSPORT_MESSAGE_WRITE,
    TRANSPORT_MESSAGE_ACCEPT,
    TRANSPORT_MESSAGE_CONNECT,
    TRANSPORT_MESSAGE_max
  } transport_message_type_t;

  typedef struct transport_configuration
  {
    uint32_t ring_size;
  } transport_configuration_t;

  typedef struct transport_message
  {
    int32_t fd;
    transport_message_type_t type;
    void *buffer;
    int32_t size;
  } transport_message_t;

  typedef struct transport_accept_request
  {
    int32_t fd;
    transport_message_type_t type;
    struct sockaddr_in client_addres;
    socklen_t client_addres_length;
  } transport_accept_request_t;

  int32_t transport_submit_receive(struct io_uring *ring, struct io_uring_cqe **cqes, uint32_t cqes_size, bool wait);
  void transport_mark_cqe(struct io_uring *ring, struct io_uring_cqe* cqe);
  intptr_t transport_queue_read(struct io_uring *ring, int32_t fd, void *buffer, uint32_t buffer_pos, uint32_t buffer_len);
  intptr_t transport_queue_write(struct io_uring *ring, int32_t fd, void *buffer, uint32_t buffer_pos, uint32_t buffer_len);
  int32_t transport_queue_accept(struct io_uring *ring, int32_t server_socket_fd);
  int32_t transport_queue_connect(struct io_uring *ring, int32_t socket_fd, const char *ip, int32_t port);
  struct io_uring *transport_initialize(transport_configuration_t *configuration);
  void transport_close();
  void transport_close_descriptor(int32_t fd);
#if defined(__cplusplus)
}
#endif

#endif
