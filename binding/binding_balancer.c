#include "binding_balancer.h"

static transport_channel_t *transport_round_robbin_balancer_next(struct transport_balancer *balancer)
{
  if (!balancer->next)
  {
    balancer->next = rlist_next(balancer->channels);
    return balancer->next;
  }
  if (balancer->next = rlist_next(balancer->next))
  {
    return balancer->next;
  }
  balancer->next = rlist_next(balancer->channels);
  return balancer->next;
}

static void transport_round_robbin_balancer_add(struct transport_balancer *balancer, transport_channel_t *channel)
{
  rlist_add_entry(balancer->channels, channel, balancer_link);
}

static void transport_round_robbin_balancer_remove(struct transport_balancer *balancer, transport_channel_t *channel)
{
  rlist_del_entry(channel, balancer_link);
}

struct transport_balancer *transport_initialize_balancer(transport_balancer_configuration_t *configuration, transport_t *transport)
{
  struct transport_balancer *balancer = smalloc(&transport->allocator, sizeof(struct transport_balancer));
  if (!balancer)
  {
    return NULL;
  }
  balancer->count = 0;
  rlist_create(balancer->channels);

  switch (configuration->type)
  {
  case TRANSPORT_BALANCER_LEAST_CONNECTIONS:
    return NULL; // TODO: Add least connections balancer
  case TRANSPORT_BALANCER_ROUND_ROBBIN:
    balancer->next = transport_round_robbin_balancer_next;
    balancer->add = transport_round_robbin_balancer_add;
    balancer->remove = transport_round_robbin_balancer_remove;
  }
}