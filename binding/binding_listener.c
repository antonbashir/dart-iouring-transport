#include "binding_listener.h"
#include <stdio.h>

void *transport_listen(void *input);

static inline void dart_post_pointer(void *pointer, Dart_Port port)
{
  Dart_CObject dart_object;
  dart_object.type = Dart_CObject_kInt64;
  dart_object.value.as_int64 = (int64_t)pointer;
  Dart_PostCObject(port, &dart_object);
};

static inline void handle_cqes(transport_listener_t *listener, int count, struct io_uring_cqe **cqes)
{
  for (size_t cqe_index = 0; cqe_index < count; cqe_index++)
  {
    struct io_uring_cqe *cqe = cqes[cqe_index];

    if (!cqe)
      continue;

    transport_message_t *message = (transport_message_t *)(cqe->user_data);
    if (!message)
    {
      io_uring_cqe_seen(&listener->transport->ring, cqe);
      break;
    }

    if (message->payload_type == TRANSPORT_PAYLOAD_ACCEPT)
    {
      ((transport_accept_payload_t *)(message->payload))->fd = cqe->res;
    }

    if (message->payload_type == TRANSPORT_PAYLOAD_READ)
    {
      ((transport_data_payload_t *)(message->payload))->size = cqe->res;
    }

    dart_post_pointer(message->payload, message->port);
    free(message);
    io_uring_cqe_seen(&listener->transport->ring, cqe);
  }

  free(cqes);
}

transport_listener_t *transport_listener_start(transport_t *transport, transport_listener_configuration_t *configuration)
{
  transport_listener_t *listener = malloc(sizeof(transport_listener_t));

  listener->transport = transport;
  listener->cqe_size = configuration->cqe_size;

  // pthread_create(&listener->thread_id, NULL, transport_listen, listener);
  //  pthread_mutex_lock(&listener->initialization_mutex);
  //  while (!listener->initialized)
  //    pthread_cond_wait(&listener->initialization_condition, &listener->initialization_mutex);
  //  pthread_mutex_unlock(&listener->initialization_mutex);
  //  pthread_cond_destroy(&listener->initialization_condition);
  //  pthread_mutex_destroy(&listener->initialization_mutex);

  return listener;
}

void transport_listener_stop(transport_listener_t *listener)
{
  listener->active = false;
  // struct io_uring_sqe *sqe = io_uring_get_sqe(&listener->transport->ring);
  // if (sqe == NULL)
  // {
  //   return;
  // }
  // io_uring_prep_nop(sqe);
  // io_uring_submit(&listener->transport->ring);
  // pthread_mutex_lock(&listener->shutdown_mutex);
  // while (listener->initialized)
  //   pthread_cond_wait(&listener->shutdown_condition, &listener->shutdown_mutex);
  // pthread_mutex_unlock(&listener->shutdown_mutex);
  // pthread_cond_destroy(&listener->shutdown_condition);
  // pthread_mutex_destroy(&listener->shutdown_mutex);

  free(listener);
}

void transport_listener_poll(transport_listener_t *listener, bool wait)
{
  int32_t result = io_uring_submit(&listener->transport->ring);
  if (result < 0)
  {
    if (result != -EBUSY)
    {
      return;
    }
  }
  struct io_uring_cqe **cqes = malloc(sizeof(struct io_uring_cqe *) * listener->cqe_size);
  result = io_uring_peek_batch_cqe(&listener->transport->ring, cqes, listener->cqe_size);
  if (result == 0)
  {
    if (!wait)
    {
      free(cqes);
      return;
    }
    result = io_uring_wait_cqe(&listener->transport->ring, cqes);
    if (result < 0)
    {
      free(cqes);
      return;
    }
    result = 1;
  }
  handle_cqes(listener, result, cqes);
}

void *transport_listen(void *input)
{
  transport_listener_t *listener = (transport_listener_t *)input;
  listener->active = true;
  //  pthread_mutex_lock(&listener->initialization_mutex);
  listener->initialized = true;
  // pthread_cond_signal(&listener->initialization_condition);
  // pthread_mutex_unlock(&listener->initialization_mutex);

  while (listener->active)
  {
    transport_listener_poll(listener, true);
  }

  if (listener->initialized)
  {
    pthread_mutex_lock(&listener->shutdown_mutex);
    listener->initialized = false;
    pthread_cond_signal(&listener->shutdown_condition);
    pthread_mutex_unlock(&listener->shutdown_mutex);
  }

  return NULL;
}

transport_message_t *transport_listener_create_message(transport_listener_t *listener, Dart_Port port, void *payload, transport_payload_type_t type)
{
  transport_message_t *message = malloc(sizeof(transport_message_t));
  message->port = port;
  message->payload = payload;
  message->payload_type = type;
  return message;
}