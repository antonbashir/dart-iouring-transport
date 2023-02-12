#include <stdio.h>

#include "binding_controller.h"
#include "binding_common.h"
#include "binding_message.h"
#include "binding_acceptor.h"
#include "binding_connector.h"
#include "binding_channel.h"
#include "binding_balancer.h"
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
};

int transport_controller_loop(va_list input)
{
  transport_controller_t *controller = va_arg(input, transport_controller_t *);
  struct transport_controller_context *context = controller->context;
  controller->active = true;
  controller->initialized = true;
  log_info("controller fiber started");
  while (likely(controller->active))
  {
    struct transport_message *message;
    if (ck_ring_dequeue_mpsc(&context->transport_message_ring, context->transport_message_buffer, &message))
    {
      if (message->action & TRANSPORT_ACTION_ADD_ACCEPTOR)
      {
        fiber_start(fiber_new(ACCEPTOR_FIBER, transport_acceptor_loop), message->data);
        continue;
      }

      if (message->action & TRANSPORT_ACTION_ADD_CONNECTOR)
      {
        fiber_start(fiber_new(CONNECTOR_FIBER, transport_connector_loop), message->data);
        continue;
      }

      if (message->action & TRANSPORT_ACTION_ADD_CHANNEL)
      {
        fiber_start(fiber_new(CHANNEL_FIBER, transport_channel_loop), message->data);
        continue;
      }

      log_info("put message");
      while (unlikely(fiber_channel_put(message->channel, message->data) != 0))
      {
        fiber_sleep(0);
      }
    }
    fiber_sleep(0);
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
  fiber_start(fiber_new(CONTROLLER_FIBER, transport_controller_loop), input);
  log_info("all fibers started");
  ev_run(loop(), 0);
  return NULL;
}

transport_controller_t *transport_controller_start(transport_t *transport, transport_controller_configuration_t *configuration)
{
  transport_controller_t *controller = malloc(sizeof(transport_controller_t));

  controller->transport = transport;
  controller->internal_ring_size = configuration->internal_ring_size;
  controller->initialized = false;
  controller->active = false;
  controller->shutdown_mutex = (pthread_mutex_t)PTHREAD_MUTEX_INITIALIZER;
  controller->shutdown_condition = (pthread_cond_t)PTHREAD_COND_INITIALIZER;
  controller->balancer = (void *)transport_initialize_balancer(configuration->balancer_configuration, transport);

  struct transport_controller_context *context = malloc(sizeof(struct transport_controller_context));
  context->transport_message_buffer = malloc(sizeof(ck_ring_buffer_t) * configuration->internal_ring_size);
  if (context->transport_message_buffer == NULL)
  {
    free(context);
    free(controller);
    return NULL;
  }
  ck_ring_init(&context->transport_message_ring, configuration->internal_ring_size);
  controller->context = context;
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