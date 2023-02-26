#include "binding_balancer.h"
#include "binding_common.h"

static transport_channel_t *transport_round_robbin_balancer_next(struct transport_balancer *balancer)
{
  if (unlikely(!balancer->next_channel))
  {
    balancer->next_channel = balancer->channels.next;
    balancer->last_channel_index = 0;
    return rlist_entry(balancer->next_channel, transport_channel_t, balancer_link);
  }
  if (balancer->last_channel_index + 1 == balancer->count)
  {
    balancer->next_channel = balancer->channels.next;
    balancer->last_channel_index = 0;
    return rlist_entry(balancer->next_channel, transport_channel_t, balancer_link);
  }
  balancer->next_channel = balancer->next_channel->next;
  balancer->last_channel_index++;
  return rlist_entry(balancer->next_channel, transport_channel_t, balancer_link);
}

static void transport_round_robbin_balancer_add(struct transport_balancer *balancer, transport_channel_t *channel)
{
  rlist_add_entry(&balancer->channels, channel, balancer_link);
  balancer->count++;
}

static void transport_round_robbin_balancer_remove(struct transport_balancer *balancer, transport_channel_t *channel)
{
  rlist_del_entry(channel, balancer_link);
  balancer->count--;
}

struct transport_balancer *transport_initialize_balancer(transport_balancer_configuration_t *configuration, transport_t *transport)
{
  struct transport_balancer *balancer = malloc(sizeof(struct transport_balancer));
  if (!balancer)
  {
    return NULL;
  }
  balancer->next_channel = NULL;
  balancer->count = 0;
  balancer->last_channel_index = 0;
  rlist_create(&balancer->channels);

  switch (configuration->type)
  {
  case TRANSPORT_BALANCER_LEAST_CONNECTIONS:
    return NULL; // TODO: Add least connections balancer
  case TRANSPORT_BALANCER_ROUND_ROBBIN:
    balancer->next = transport_round_robbin_balancer_next;
    balancer->add = transport_round_robbin_balancer_add;
    balancer->remove = transport_round_robbin_balancer_remove;
  }

  return balancer;
}