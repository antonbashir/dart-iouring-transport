#ifndef BINDING_TRANSPORT_H_INCLUDED
#define BINDING_TRANSPORT_H_INCLUDED
#include <stdio.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <liburing.h>
#include <string.h>
#include <errno.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdint.h>

#if defined(__cplusplus)
extern "C"
{
#endif
  typedef struct transport_configuration
  {
    uint32_t ring_size;
  } transport_configuration_t;

  typedef struct transport_message
  {
    void *buffer;
    int32_t fd;
  } transport_message_t;

  typedef struct transport_accept_request
  {
    struct sockaddr_in client_addres;
    socklen_t client_addres_length;
    int32_t fd;
  } transport_accept_request_t;

  int32_t transport_initialize(transport_configuration_t *configuration);
  void transport_close();
#if defined(__cplusplus)
}
#endif

#endif
