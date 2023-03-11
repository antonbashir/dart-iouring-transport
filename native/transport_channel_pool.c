#include "transport_channel_pool.h"
#include "transport_common.h"

static transport_channel_t *transport_channel_pool_next(struct transport_channel_pool *channel_pool)
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

static void transport_channel_pool_add(struct transport_channel_pool *channel_pool, transport_channel_t *channel)
{
  rlist_add_entry(&channel_pool->channels, channel, channel_pool_link);
  channel_pool->count++;
}

static void transport_channel_pool_remove(struct transport_channel_pool *channel_pool, transport_channel_t *channel)
{
  rlist_del_entry(channel, channel_pool_link);
  channel_pool->count--;
}

struct transport_channel_pool *transport_channel_pool_initialize()
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

  return channel_pool;
}
