#include "binding_controller.h"
#include <stdio.h>

#include "ck_ring.h"
#include "ck_backoff.h"

static int ring_retry_max_count = 3;

void *transport_controller_loop(void *input);

struct transport_controller_ring
{
  ck_ring_buffer_t *transport_message_buffer;
  ck_ring_t transport_message_ring;
  ck_backoff_t ring_send_backoff;
};

static inline void dart_post_pointer(void *pointer, Dart_Port port)
{
  Dart_CObject dart_object;
  dart_object.type = Dart_CObject_kInt64;
  dart_object.value.as_int64 = (int64_t)pointer;
  Dart_PostCObject(port, &dart_object);
};

static inline void handle_cqes(transport_controller_t *controller, int count, struct io_uring_cqe **cqes)
{
  for (size_t cqe_index = 0; cqe_index < count; cqe_index++)
  {
    struct io_uring_cqe *cqe = cqes[cqe_index];

    if (!cqe)
      continue;

    transport_message_t *message = (transport_message_t *)(cqe->user_data);
    if (!message)
    {
      io_uring_cqe_seen(&controller->transport->ring, cqe);
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
    io_uring_cqe_seen(&controller->transport->ring, cqe);
  }

  free(cqes);
}

static inline void transport_controller_handle_message(transport_controller_t *controller, transport_message_t *message)
{
  struct io_uring_sqe *sqe = io_uring_get_sqe(&controller->transport->ring);
  if (sqe == NULL)
  {
    return;
  }

  if (message->payload_type == TRANSPORT_PAYLOAD_ACCEPT)
  {
    transport_accept_payload_t *accept_payload = (transport_accept_payload_t *)message->payload;
    io_uring_prep_accept(sqe, accept_payload->fd, (struct sockaddr *)&accept_payload->client_addres, &accept_payload->client_addres_length, 0);
    io_uring_sqe_set_data(sqe, message);
  }
  if (message->payload_type == TRANSPORT_PAYLOAD_CONNECT)
  {
    transport_accept_payload_t *connect_payload = (transport_accept_payload_t *)message->payload;
    io_uring_prep_connect(sqe, connect_payload->fd, (struct sockaddr *)&connect_payload->client_addres, connect_payload->client_addres_length);
    io_uring_sqe_set_data(sqe, message);
  }
  if (message->payload_type == TRANSPORT_PAYLOAD_READ)
  {
    transport_data_payload_t *read_payload = (transport_data_payload_t *)message->payload;
    io_uring_prep_read(sqe, read_payload->fd, read_payload->position, read_payload->size, read_payload->offset);
    io_uring_sqe_set_data(sqe, message);
  }
  if (message->payload_type == TRANSPORT_PAYLOAD_WRITE)
  {
    transport_data_payload_t *write_payload = (transport_data_payload_t *)message->payload;
    io_uring_prep_write(sqe, write_payload->fd, write_payload->position, write_payload->size, write_payload->offset);
    io_uring_sqe_set_data(sqe, message);
  }
}

transport_message_t *transport_controller_create_message(transport_controller_t *controller, Dart_Port port, void *payload, transport_payload_type_t type)
{
  transport_message_t *message = malloc(sizeof(transport_message_t));
  message->port = port;
  message->payload = payload;
  message->payload_type = type;
  return message;
}

transport_controller_t *transport_controller_start(transport_t *transport, transport_controller_configuration_t *configuration)
{
  transport_controller_t *controller = malloc(sizeof(transport_controller_t));

  controller->transport = transport;
  controller->cqe_size = configuration->cqe_size;
  struct transport_controller_ring *ring = malloc(sizeof(struct transport_controller_ring));
  ring->transport_message_buffer = malloc(sizeof(ck_ring_buffer_t) * configuration->cqe_size * 2);
  if (ring->transport_message_buffer == NULL)
  {
    free(ring);
    free(controller);
    return NULL;
  }
  ck_ring_init(&ring->transport_message_ring, configuration->cqe_size);
  ring_retry_max_count = 3;

  controller->message_ring = ring;

  pthread_create(&controller->thread_id, NULL, transport_controller_loop, controller);
  pthread_mutex_lock(&controller->initialization_mutex);
  while (!controller->initialized)
    pthread_cond_wait(&controller->initialization_condition, &controller->initialization_mutex);
  pthread_mutex_unlock(&controller->initialization_mutex);
  pthread_cond_destroy(&controller->initialization_condition);
  pthread_mutex_destroy(&controller->initialization_mutex);

  return controller;
}

void transport_controller_stop(transport_controller_t *controller)
{
  controller->active = false;
  struct io_uring_sqe *sqe = io_uring_get_sqe(&controller->transport->ring);
  if (sqe == NULL)
  {
    return;
  }
  io_uring_prep_nop(sqe);
  io_uring_submit(&controller->transport->ring);
  pthread_mutex_lock(&controller->shutdown_mutex);
  while (controller->initialized)
    pthread_cond_wait(&controller->shutdown_condition, &controller->shutdown_mutex);
  pthread_mutex_unlock(&controller->shutdown_mutex);
  pthread_cond_destroy(&controller->shutdown_condition);
  pthread_mutex_destroy(&controller->shutdown_mutex);

  free(controller);
}

void *transport_controller_loop(void *input)
{
  transport_controller_t *controller = (transport_controller_t *)input;
  struct transport_controller_ring *ring = (struct transport_controller_ring *)controller->message_ring;
  controller->active = true;
  pthread_mutex_lock(&controller->initialization_mutex);
  controller->initialized = true;
  pthread_cond_signal(&controller->initialization_condition);
  pthread_mutex_unlock(&controller->initialization_mutex);

  while (controller->active)
  {
    transport_message_t *message;
    if (ck_ring_dequeue_mpsc(&ring->transport_message_ring, ring->transport_message_buffer, &message))
    {
      transport_controller_handle_message(controller, message);
      int32_t result = io_uring_submit(&controller->transport->ring);
      if (result < 0)
      {
        if (result != -EBUSY)
        {
          continue;
        }
      }
      struct io_uring_cqe **cqes = malloc(sizeof(struct io_uring_cqe *) * controller->cqe_size);
      result = io_uring_peek_batch_cqe(&controller->transport->ring, cqes, controller->cqe_size);
      if (result == 0)
      {
        free(cqes);
        continue;
      }
      handle_cqes(controller, result, cqes);
      sleep(1);
    }
  }

  if (controller->initialized)
  {
    pthread_mutex_lock(&controller->shutdown_mutex);
    controller->initialized = false;
    pthread_cond_signal(&controller->shutdown_condition);
    pthread_mutex_unlock(&controller->shutdown_mutex);
  }

  return NULL;
}

bool transport_controller_send(transport_controller_t *controller, transport_message_t *message)
{
  if (controller->active == false)
  {
    return false;
  }
  if (io_uring_sq_space_left(&controller->transport->ring) <= 1)
  {
    return false;
  }
  struct transport_controller_ring *ring = (struct transport_controller_ring *)controller->message_ring;
  int count = 0;
  while (!ck_ring_enqueue_mpsc(&ring->transport_message_ring, ring->transport_message_buffer, message))
  {
    ck_backoff_eb(&ring->ring_send_backoff);
    if (++count >= ring_retry_max_count)
    {
      ring->ring_send_backoff = CK_BACKOFF_INITIALIZER;
      return false;
    }
  }
  ring->ring_send_backoff = CK_BACKOFF_INITIALIZER;
  return true;
}