#include "binding_channel_pool.h"
#include "binding_common.h"

static transport_channel_t *transport_round_robbin_channel_pool_next(struct transport_channel_pool *channel_pool)
{
  if (!channel_pool->next_channel)
  {
    channel_pool->next_channel = channel_pool->channels.next;
    channel_pool->last_channel_index = 0;
    return rlist_entry(channel_pool->next_channel, transport_channel_t, channel_pool_link);
  }
  if (channel_pool->last_channel_index + 1 == channel_pool->count)
  {
    channel_pool->next_channel = channel_pool->channels.next;
    channel_pool->last_channel_index = 0;
    return rlist_entry(channel_pool->next_channel, transport_channel_t, channel_pool_link);
  }
  channel_pool->next_channel = channel_pool->next_channel->next;
  channel_pool->last_channel_index++;
  return rlist_entry(channel_pool->next_channel, transport_channel_t, channel_pool_link);
}

static void transport_round_robbin_channel_pool_add(struct transport_channel_pool *channel_pool, transport_channel_t *channel)
{
  rlist_add_entry(&channel_pool->channels, channel, channel_pool_link);
  channel_pool->count++;
}

static void transport_round_robbin_channel_pool_remove(struct transport_channel_pool *channel_pool, transport_channel_t *channel)
{
  rlist_del_entry(channel, channel_pool_link);
  channel_pool->count--;
}

static transport_channel_t *transport_least_connections_channel_pool_next(struct transport_channel_pool *channel_pool)
{
  transport_channel_t *channel, *temp;
  transport_channel_t *selected = rlist_entry(channel_pool->channels.next, transport_channel_t, channel_pool_link);
  rlist_foreach_entry_safe(channel, &channel_pool->channels, channel_pool_link, temp)
  {
    if (channel->used_buffers_count < selected->used_buffers_count)
    {
      selected = channel;
    }
  }
  return rlist_entry(selected, transport_channel_t, channel_pool_link);
}

static void transport_least_connections_channel_pool_add(struct transport_channel_pool *channel_pool, transport_channel_t *channel)
{
  rlist_add_entry(&channel_pool->channels, channel, channel_pool_link);
  channel_pool->count++;
}

static void transport_least_connections_channel_pool_remove(struct transport_channel_pool *channel_pool, transport_channel_t *channel)
{
  rlist_del_entry(channel, channel_pool_link);
  channel_pool->count--;
}

struct transport_channel_pool *transport_channel_pool_initialize(transport_channel_pool_mode_t mode)
{
  struct transport_channel_pool *channel_pool = malloc(sizeof(struct transport_channel_pool));
  if (!channel_pool)
  {
    return NULL;
  }
  channel_pool->next_channel = NULL;
  channel_pool->count = 0;
  channel_pool->last_channel_index = 0;
  rlist_create(&channel_pool->channels);

  switch (mode)
  {
  case TRANSPORT_CHANNEL_POOL_ROUND_ROBBIN:
    channel_pool->next = transport_round_robbin_channel_pool_next;
    channel_pool->add = transport_round_robbin_channel_pool_add;
    channel_pool->remove = transport_round_robbin_channel_pool_remove;
    break;
  case TRANSPORT_CHANNEL_POOL_LEAST_CONNECTIONS:
    channel_pool->next = transport_least_connections_channel_pool_next;
    channel_pool->add = transport_least_connections_channel_pool_add;
    channel_pool->remove = transport_least_connections_channel_pool_remove;
    break;
  }

  return channel_pool;
}
