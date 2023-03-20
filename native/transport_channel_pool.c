#include "transport_channel_pool.h"
#include "transport_common.h"

transport_channel_t *transport_channel_pool_next(transport_channel_pool_t *pool)
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

void transport_channel_pool_add(transport_channel_pool_t *pool, transport_channel_t *channel)
{
  rlist_add_entry(&pool->channels, channel, channel_pool_link);
  pool->count++;
}

void transport_channel_pool_remove(transport_channel_pool_t *pool, transport_channel_t *channel)
{
  rlist_del_entry(channel, channel_pool_link);
  pool->count--;
}

transport_channel_pool_t *transport_channel_pool_initialize()
{
  transport_channel_pool_t *channel_pool = malloc(sizeof(transport_channel_pool_t));
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
