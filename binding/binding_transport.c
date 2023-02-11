#include "binding_transport.h"
#include "dart/dart_api.h"
#include <stdio.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <liburing.h>
#include <string.h>
#include <errno.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdint.h>
#include <pthread.h>
#include <sys/time.h>
#include "binding_common.h"
#include "fiber.h"
#include "memory.h"
#include "cbus.h"

transport_t *transport_initialize(transport_configuration_t *configuration)
{
  transport_t *transport = malloc(sizeof(transport_t));
  if (!transport)
  {
    return NULL;
  }

  int32_t status = io_uring_queue_init(configuration->ring_size, &transport->ring, 0);
  if (status)
  {
    fprintf(stderr, "io_urig init error: %d", status);
    free(&transport->ring);
    return NULL;
  }

  quota_init(&transport->quota, configuration->memory_quota);
  slab_arena_create(&transport->arena, &transport->quota, 0, configuration->slab_size, MAP_PRIVATE);
  slab_cache_create(&transport->cache, &transport->arena);
  float actual_allocation_factor;
  small_alloc_create(&transport->allocator,
                     &transport->cache,
                     configuration->slab_allocation_minimal_object_size,
                     configuration->slab_allocation_granularity,
                     configuration->slab_allocation_factor,
                     &actual_allocation_factor);

  // log_info("transport initialized");
  return transport;
}

void transport_close(transport_t *transport)
{
  io_uring_queue_exit(&transport->ring);

  small_alloc_destroy(&transport->allocator);
  slab_cache_destroy(&transport->cache);
  slab_arena_destroy(&transport->arena);

  // log_info("transport closed");
  free(transport);
}

static int fiber_func_f_2(va_list ap)
{
  (void)ap;
  printf("hello, fiber 2!\n");
  fiber_sleep(0);
  printf("buy, fiber 2!\n");
  return 0;
}

static int fiber_func_f_1(va_list ap)
{
  (void)ap;
  printf("hello, fiber 1!\n");
  struct fiber *c = fiber_new("func_2", fiber_func_f_2);
  fiber_wakeup(c);
  fiber_sleep(0);
  printf("good, fiber 2!\n");
  printf("buy, fiber 1!\n");
  return 0;
}

void test_func()
{
  memory_init();
  fiber_init(fiber_c_invoke);
  cbus_init();
  struct fiber *c = fiber_new("func_1", fiber_func_f_1);
  fiber_wakeup(c);
  ev_run(loop(), 0);
}
