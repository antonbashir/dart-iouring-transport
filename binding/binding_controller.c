#include <stdio.h>
#include <sys/eventfd.h>
#include "binding_controller.h"
#include "binding_common.h"
#include "binding_message.h"
#include "binding_acceptor.h"
#include "binding_connector.h"
#include "binding_channel.h"
#include "binding_logger.h"
#include "ck_ring.h"
#include "ck_backoff.h"
#include "ck_spinlock.h"
#include "fiber.h"
#include "fiber_channel.h"
#include "memory.h"
#include "cbus.h"

#define CONTROLLER_FIBER "controller"
#define ACCEPTOR_FIBER "acceptor"
#define CONNECTOR_FIBER "connector"
#define CHANNEL_FIBER "channel"

struct transport_controller_context
{
  ck_ring_buffer_t *transport_message_buffer;
  ck_ring_t transport_message_ring;
  ck_backoff_t ring_send_backoff;
  struct transport_channel *channel;
  struct transport_acceptor *acceptor;
};

int transport_controller_consumer_loop(va_list input)
{
  transport_controller_t *controller = va_arg(input, transport_controller_t *);
  struct transport_controller_context *context = controller->context;
  struct io_uring *ring = controller->ring;
  controller->active = true;
  controller->initialized = true;
  log_info("controller fiber started");
  int count = 0;
  struct io_uring_cqe *cqe;
  unsigned int head;
  while (controller->active)
  {
    if (likely(io_uring_wait_cqe(ring, &cqe) == 0))
    {
      count = 0;
      io_uring_for_each_cqe(ring, head, cqe)
      {
        ++count;

        if (unlikely(cqe->res < 0))
        {
          if (cqe->res == -EPIPE)
          {
            continue;
          }

          log_error("controller process cqe with result '%s' and user_data %d", strerror(-cqe->res), cqe->user_data);
          continue;
        }

        if ((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_ACCEPT))
        {
          transport_channel_handle_accept(context->channel, cqe->res);
          continue;
        }

        if ((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_READ))
        {
          transport_channel_handle_read(context->channel, cqe);
          continue;
        }

        if ((uint64_t)(cqe->user_data & TRANSPORT_PAYLOAD_WRITE))
        {
          transport_channel_handle_write(context->channel, cqe);
          continue;
        }
      }
      io_uring_cq_advance(ring, count);
    }
  }

  if (controller->initialized)
  {
    pthread_mutex_lock(&controller->shutdown_mutex);
    controller->initialized = false;
    pthread_cond_signal(&controller->shutdown_condition);
    pthread_mutex_unlock(&controller->shutdown_mutex);
  }
}

void *transport_controller_run(void *input)
{
  memory_init();
  fiber_init(fiber_c_invoke);
  cbus_init();
  struct fiber *controller_fiber = fiber_new(CONTROLLER_FIBER, transport_controller_consumer_loop);
  fiber_start(controller_fiber, input);
  fiber_wakeup(controller_fiber);
  ev_now_update(loop());
  ev_run(loop(), 0);
  return NULL;
}

transport_controller_t *transport_controller_start(transport_t *transport,
                                                   transport_acceptor_t *acceptor,
                                                   transport_channel_t *channel,
                                                   transport_controller_configuration_t *configuration)
{
  transport_controller_t *controller = malloc(sizeof(transport_controller_t));

  controller->transport = transport;
  controller->internal_ring_size = configuration->internal_ring_size;
  controller->ring_retry_max_count = configuration->ring_retry_max_count;
  controller->initialized = false;
  controller->active = false;
  controller->shutdown_mutex = (pthread_mutex_t)PTHREAD_MUTEX_INITIALIZER;
  controller->shutdown_condition = (pthread_cond_t)PTHREAD_COND_INITIALIZER;

  struct transport_controller_context *context = malloc(sizeof(struct transport_controller_context));

  controller->ring = malloc(sizeof(struct io_uring));
  int32_t status = io_uring_queue_init(8192, controller->ring, 0);
  if (status)
  {
    log_error("io_urig init error: %d", status);
    free(controller->ring);
    free(context);
    return NULL;
  }

  context->transport_message_buffer = malloc(sizeof(ck_ring_buffer_t) * configuration->internal_ring_size);
  if (context->transport_message_buffer == NULL)
  {
    free(context);
    free(controller);
    return NULL;
  }
  ck_ring_init(&context->transport_message_ring, configuration->internal_ring_size);
  controller->context = context;
  context->acceptor = acceptor;
  context->channel = channel;
  pthread_create(&controller->thread_id, NULL, transport_controller_run, controller);
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

bool transport_controller_send(transport_controller_t *controller, void *message)
{
  struct transport_controller_context *context = (struct transport_controller_context *)controller->context;
  int count = 0;
  while (unlikely(!ck_ring_enqueue_mpsc(&context->transport_message_ring, context->transport_message_buffer, message)))
  {
    ck_backoff_eb(&context->ring_send_backoff);
    if (++count >= controller->ring_retry_max_count)
    {
      context->ring_send_backoff = CK_BACKOFF_INITIALIZER;
      return false;
    }
  }
  context->ring_send_backoff = CK_BACKOFF_INITIALIZER;
  return true;
}