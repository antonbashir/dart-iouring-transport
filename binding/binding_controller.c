#include "binding_controller.h"
#include "binding_common.h"
#include <stdio.h>

#include "ck_ring.h"
#include "ck_backoff.h"
#include "ck_spinlock.h"

static int ring_retry_max_count = 3;

void *transport_controller_loop(void *input);

struct transport_controller_ring
{
  ck_ring_buffer_t *transport_message_buffer;
  ck_ring_t transport_message_ring;
  ck_backoff_t ring_send_backoff;
  ck_spinlock_cas_t submit_lock;
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
    // log_info("ring cqe %d result %d", cqe_index, cqe->res);

    if (unlikely(cqe->res < 0))
    {
      if (cqe->user_data)
      {
        free((void *)cqe->user_data);
      }
      io_uring_cqe_seen(&controller->transport->ring, cqe);
      continue;
    }

    if (unlikely(!cqe->user_data))
    {
      io_uring_cqe_seen(&controller->transport->ring, cqe);
      continue;
    }

    transport_message_t *message = (transport_message_t *)(cqe->user_data);
    // log_info("ring cqe %d message type %d", cqe_index, message->payload_type);
    if (likely(message->payload_type == TRANSPORT_PAYLOAD_READ))
    {
      ((transport_data_payload_t *)(message->payload))->size = cqe->res;
    }

    if (unlikely(message->payload_type == TRANSPORT_PAYLOAD_ACCEPT))
    {
      ((transport_accept_payload_t *)(message->payload))->fd = cqe->res;
    }

    dart_post_pointer(message->payload, message->port);
    free(message);
    io_uring_cqe_seen(&controller->transport->ring, cqe);
  }
}

static inline void handle_message(transport_controller_t *controller, transport_message_t *message)
{
  struct io_uring_sqe *sqe = io_uring_get_sqe(&controller->transport->ring);
  if (unlikely(sqe == NULL))
  {
    return;
  }

  if (likely(message->payload_type == TRANSPORT_PAYLOAD_READ))
  {
    transport_data_payload_t *read_payload = (transport_data_payload_t *)message->payload;
    io_uring_prep_read(sqe, read_payload->fd, (void *)read_payload->position, read_payload->buffer_size, read_payload->offset);
    io_uring_sqe_set_data(sqe, message);
    return;
  }
  if (likely(message->payload_type == TRANSPORT_PAYLOAD_WRITE))
  {
    transport_data_payload_t *write_payload = (transport_data_payload_t *)message->payload;
    io_uring_prep_write(sqe, write_payload->fd, (void *)write_payload->position, write_payload->size, write_payload->offset);
    io_uring_sqe_set_data(sqe, message);
    return;
  }
  if (message->payload_type == TRANSPORT_PAYLOAD_ACCEPT)
  {
    transport_accept_payload_t *accept_payload = (transport_accept_payload_t *)message->payload;
    io_uring_prep_accept(sqe, accept_payload->fd, (struct sockaddr *)&accept_payload->client_addres, &accept_payload->client_addres_length, 0);
    io_uring_sqe_set_data(sqe, message);
    return;
  }
  if (message->payload_type == TRANSPORT_PAYLOAD_CONNECT)
  {
    transport_accept_payload_t *connect_payload = (transport_accept_payload_t *)message->payload;
    io_uring_prep_connect(sqe, connect_payload->fd, (struct sockaddr *)&connect_payload->client_addres, connect_payload->client_addres_length);
    io_uring_sqe_set_data(sqe, message);
    return;
  }
}

transport_controller_t *transport_controller_start(transport_t *transport, transport_controller_configuration_t *configuration)
{
  transport_controller_t *controller = malloc(sizeof(transport_controller_t));

  controller->transport = transport;
  controller->cqe_size = configuration->cqe_size;
  controller->batch_message_limit = configuration->batch_message_limit;
  controller->internal_ring_size = configuration->internal_ring_size;
  controller->initialized = false;
  controller->active = false;
  controller->suspended_mutex = (pthread_mutex_t)PTHREAD_MUTEX_INITIALIZER;
  controller->suspended_condition = (pthread_cond_t)PTHREAD_COND_INITIALIZER;
  controller->shutdown_mutex = (pthread_mutex_t)PTHREAD_MUTEX_INITIALIZER;
  controller->shutdown_condition = (pthread_cond_t)PTHREAD_COND_INITIALIZER;

  struct transport_controller_ring *ring = malloc(sizeof(struct transport_controller_ring));
  ring->transport_message_buffer = malloc(sizeof(ck_ring_buffer_t) * configuration->internal_ring_size);
  ck_spinlock_cas_init(&ring->submit_lock);
  if (ring->transport_message_buffer == NULL)
  {
    free(ring);
    free(controller);
    return NULL;
  }
  ck_ring_init(&ring->transport_message_ring, configuration->internal_ring_size);
  ring_retry_max_count = 3;
  controller->message_ring = ring;
  pthread_create(&controller->thread_id, NULL, transport_controller_loop, controller);
  return controller;
}

void transport_controller_stop(transport_controller_t *controller)
{
  pthread_mutex_lock(&controller->shutdown_mutex);
  log_info("controller is stopping");
  controller->active = false;
  while (controller->initialized)
    pthread_cond_wait(&controller->shutdown_condition, &controller->shutdown_mutex);
  pthread_mutex_unlock(&controller->shutdown_mutex);
  pthread_cond_destroy(&controller->shutdown_condition);
  pthread_mutex_destroy(&controller->shutdown_mutex);
  free(controller);
  log_info("controller is stopped");
}

void *transport_controller_loop(void *input)
{
  transport_controller_t *controller = (transport_controller_t *)input;
  struct transport_controller_ring *ring = (struct transport_controller_ring *)controller->message_ring;
  controller->active = true;
  controller->initialized = true;
  while (likely(controller->active))
  {
    unsigned head;
    unsigned count = 0;
    struct io_uring_cqe *cqe;
    io_uring_for_each_cqe(&controller->transport->ring, head, cqe)
    {
      ++count;
      if (unlikely(cqe->res < 0 || !cqe->user_data))
      {
        if (cqe->user_data)
        {
          free((void *)cqe->user_data);
        }
        continue;
      }
      transport_message_t *message = (transport_message_t *)(cqe->user_data);
      if (message->payload_type == TRANSPORT_PAYLOAD_READ)
      {
        ((transport_data_payload_t *)(message->payload))->size = cqe->res;
      }
      if (message->payload_type == TRANSPORT_PAYLOAD_ACCEPT)
      {
        ((transport_accept_payload_t *)(message->payload))->fd = cqe->res;
      }
      dart_post_pointer(message->payload, message->port);
      free(message);
    }
    io_uring_cq_advance(&controller->transport->ring, count);
    transport_message_t *message;
    while (ck_ring_dequeue_mpsc(&ring->transport_message_ring, ring->transport_message_buffer, &message))
    {
      struct io_uring_sqe *sqe = io_uring_get_sqe(&controller->transport->ring);
      if (message->payload_type == TRANSPORT_PAYLOAD_READ)
      {
        transport_data_payload_t *read_payload = (transport_data_payload_t *)message->payload;
        io_uring_prep_read(sqe, read_payload->fd, (void *)read_payload->position, read_payload->buffer_size, read_payload->offset);
        io_uring_sqe_set_data(sqe, message);
        io_uring_submit_and_wait(&controller->transport->ring, 1);
        continue;
      }
      if (message->payload_type == TRANSPORT_PAYLOAD_WRITE)
      {
        transport_data_payload_t *write_payload = (transport_data_payload_t *)message->payload;
        io_uring_prep_write(sqe, write_payload->fd, (void *)write_payload->position, write_payload->size, write_payload->offset);
        io_uring_sqe_set_data(sqe, message);
        io_uring_submit_and_wait(&controller->transport->ring, 1);
        continue;
      }
      if (message->payload_type == TRANSPORT_PAYLOAD_ACCEPT)
      {
        transport_accept_payload_t *accept_payload = (transport_accept_payload_t *)message->payload;
        io_uring_prep_accept(sqe, accept_payload->fd, (struct sockaddr *)&accept_payload->client_addres, &accept_payload->client_addres_length, 0);
        io_uring_sqe_set_data(sqe, message);
        io_uring_submit(&controller->transport->ring);
        continue;
      }
      if (message->payload_type == TRANSPORT_PAYLOAD_CONNECT)
      {
        transport_accept_payload_t *connect_payload = (transport_accept_payload_t *)message->payload;
        io_uring_prep_connect(sqe, connect_payload->fd, (struct sockaddr *)&connect_payload->client_addres, connect_payload->client_addres_length);
        io_uring_sqe_set_data(sqe, message);
        io_uring_submit(&controller->transport->ring);
        continue;
      }
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
  if (unlikely(!controller->active))
  {
    return false;
  }

  if (unlikely(io_uring_sq_space_left(&controller->transport->ring) <= 1))
  {
    return false;
  }

  struct transport_controller_ring *ring = (struct transport_controller_ring *)controller->message_ring;
  int count = 0;

  while (unlikely(!ck_ring_enqueue_mpsc(&ring->transport_message_ring, ring->transport_message_buffer, message)))
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