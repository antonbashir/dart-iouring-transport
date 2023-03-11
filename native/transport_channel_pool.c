#include "transport_channel_pool.h"
#include "transport_common.h"

transport_channel_t *transport_channel_pool_next(struct transport_channel_pool *pool)
{
  if (unlikely(!pool->next_channel))
  {
    pool->next_channel = pool->channels.next;
    pool->next_channel_index = 0;
    return rlist_entry(pool->next_channel, transport_channel_t, channel_pool_link);
  }
  if (pool->next_channel_index + 1 == pool->count)
  {
    pool->next_channel = pool->channels.next;
    pool->next_channel_index = 0;
    return rlist_entry(pool->next_channel, transport_channel_t, channel_pool_link);
  }
  pool->next_channel = pool->next_channel->next;
  pool->next_channel_index++;
  return rlist_entry(pool->next_channel, transport_channel_t, channel_pool_link);
}

void transport_channel_pool_add(struct transport_channel_pool *pool, transport_channel_t *channel)
{
  rlist_add_entry(&pool->channels, channel, channel_pool_link);
  pool->count++;
}

void transport_channel_pool_remove(struct transport_channel_pool *pool, transport_channel_t *channel)
{
  rlist_del_entry(channel, channel_pool_link);
  pool->count--;
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
  channel_pool->next_channel_index = 0;
  rlist_create(&channel_pool->channels);

  return channel_pool;
}
