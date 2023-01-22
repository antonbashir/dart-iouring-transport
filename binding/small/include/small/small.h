#ifndef INCLUDES_TARANTOOL_SMALL_SMALL_H
#define INCLUDES_TARANTOOL_SMALL_SMALL_H
/*
 * Copyright 2010-2016, Tarantool AUTHORS, please see AUTHORS file.
 *
 * Redistribution and use in source and binary forms, with or
 * without modification, are permitted provided that the following
 * conditions are met:
 *
 * 1. Redistributions of source code must retain the above
 *    copyright notice, this list of conditions and the
 *    following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above
 *    copyright notice, this list of conditions and the following
 *    disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY <COPYRIGHT HOLDER> ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL
 * <COPYRIGHT HOLDER> OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
 * THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */
#include <stdint.h>
#include "mempool.h"
#include "slab_arena.h"
#include "lifo.h"
#include "small_class.h"

#if defined(__cplusplus)
extern "C" {
#endif /* defined(__cplusplus) */

/**
 * Small object allocator.
 *
 * The allocator consists of a collection of mempools.
 *
 * There are two containers of pools:
 *
 * pools for objects of size 8-500 bytes are stored in an array,
 * where pool->objsize of each array member is a multiple of 8-16
 * (value defined in STEP_SIZE constant). These are
 * "stepped" pools, since pool->objsize of each next pool in the
 * array differs from the  previous size by a fixed step size.
 *
 * For example, there is a pool for size range 16-32,
 * another one for 32-48, 48-64, etc. This makes the look up
 * procedure for small allocations just a matter of getting an
 * array index via a bit shift. All stepped pools are initialized
 * when an instance of small_alloc is created.
 *
 * Objects of size beyond the stepped pools range (the upper limit
 * is usually around 300 bytes), are stored in pools with a size
 * which is a multiple of alloc_factor. alloc_factor is itself
 * a configuration constant in the range (1.0, 2.0]. I.e. imagine
 * alloc_factor is 1.1, then there are pools for objects of size
 * 300-330, 330-363, and so on. These pools are created upon first
 * allocation within given range, and stored in a red-black tree.
 *
 * Initially this red-black tree contains only a pool for
 * alloc->object_max.
 * When a request for a new allocation of sz bytes arrives
 * and it can not be satisfied from a stepped pool,
 * a search for a nearest factored pool is made in the tree.
 *
 * If, for the nearest found factored pool:
 *
 * pool->objsize > sz * alloc_factor,
 *
 * (i.e. pool object size is too big) a new factored pool is
 * created and inserted into the tree.
 *
 * This way the tree only contains factored pools for sizes
 * which are actually used by the server, and can be kept
 * small.
 */

/** Basic constants of small object allocator. */
enum {
	/** How many factored pools there can be. */
	FACTOR_POOL_MAX = 1024,
};

enum small_opt {
	SMALL_DELAYED_FREE_MODE
};

/**
 * A mempool to store objects sized within one multiple of
 * alloc_factor. Is a member of the red-black tree which
 * contains all such pools.
 *
 * Example: let's assume alloc_factor is 1.1. There will be an
 * instance of factor_pool for objects of size from 300 to 330,
 * from 330 to 363, and so on.
 */
struct factor_pool
{
	/** the pool itself. */
	struct mempool pool;
	/**
	 * Objects starting from this size and up to
	 * pool->objsize are stored in this factored
	 * pool.
	 */
	size_t objsize_min;
};

/**
 * Free mode
 */
enum small_free_mode {
	/** Free objects immediately. */
	SMALL_FREE,
	/** Collect garbage after delayed free. */
	SMALL_COLLECT_GARBAGE,
	/** Postpone deletion of objects. */
	SMALL_DELAYED_FREE,
};

/** A slab allocator for a wide range of object sizes. */
struct small_alloc {
	struct slab_cache *cache;
	/** A cache for nodes in the factor_pools tree. */
	struct factor_pool factor_pool_cache[FACTOR_POOL_MAX];
	/* factor_pool_cache array real size */
	uint32_t factor_pool_cache_size;
	/**
	 * List of mempool which objects to be freed if delayed free mode.
	 */
	struct lifo delayed;
	/**
	 * List of large allocations by malloc() to be freed in delayed mode.
	 */
	struct lifo delayed_large;
	/**
	 * The factor used for factored pools. Must be > 1.
	 * Is provided during initialization.
	 */
	float factor;
	/** Small class for this allocator */
	struct small_class small_class;
	uint32_t objsize_max;
	/**
	 * Free mode.
	 */
	enum small_free_mode free_mode;
};

/**
 * Initialize a small memory allocator.
 * @param alloc - instance to create.
 * @param cache - pointer to used slab cache.
 * @param objsize_min - minimal object size.
 * @param granularity - alignment of objects in pools
 * @param alloc_factor - desired factor of growth object size.
 * Must be in (1, 2] range.
 * @param actual_alloc_factor real allocation factor calculated the basis of
 *        desired alloc_factor
 */
void
small_alloc_create(struct small_alloc *alloc, struct slab_cache *cache,
		   uint32_t objsize_min, unsigned granularity,
		   float alloc_factor, float *actual_alloc_factor);

/**
 * Enter or leave delayed mode - in delayed mode smfree_delayed()
 * doesn't free chunks but puts them into a pool.
 */
void
small_alloc_setopt(struct small_alloc *alloc, enum small_opt opt, bool val);

/** Destroy the allocator and all allocated memory. */
void
small_alloc_destroy(struct small_alloc *alloc);

/** Allocate a piece of memory in the small allocator.
 *
 * @retval NULL   the requested size is beyond objsize_max
 *                or out of memory
 */
void *
smalloc(struct small_alloc *alloc, size_t size);

/** Free memory chunk allocated by the small allocator. */
/**
 * Free a small objects.
 *
 * This boils down to finding the object's mempool and delegating
 * to mempool_free().
 */
void
smfree(struct small_alloc *alloc, void *ptr, size_t size);

/**
 * Free memory chunk allocated by the small allocator
 * if not in snapshot mode, otherwise put to the delayed
 * free list.
 */
void
smfree_delayed(struct small_alloc *alloc, void *ptr, size_t size);

/**
 * @brief Return an unique index associated with a chunk allocated
 * by the allocator.
 *
 * This index space is more dense than the pointers space,
 * especially in the least significant bits.  This number is
 * needed because some types of box's indexes (e.g. BITSET) have
 * better performance then they operate on sequential offsets
 * (i.e. dense space) instead of memory pointers (sparse space).
 *
 * The calculation is based on SLAB number and the position of an
 * item within it. Current implementation only guarantees that
 * adjacent chunks from one SLAB will have consecutive indexes.
 * That is, if two chunks were sequentially allocated from one
 * chunk they will have sequential ids. If a second chunk was
 * allocated from another SLAB thеn the difference between indexes
 * may be more than one.
 *
 * @param ptr pointer to memory allocated in small_alloc
 * @return unique index
 */
size_t
small_ptr_compress(struct small_alloc *alloc, void *ptr);

/**
 * Perform the opposite action of small_ptr_compress().
 */
void *
small_ptr_decompress(struct small_alloc *alloc, size_t val);

typedef int (*mempool_stats_cb)(const struct mempool_stats *stats,
				void *cb_ctx);

void
small_stats(struct small_alloc *alloc,
	    struct small_stats *totals,
	    mempool_stats_cb cb, void *cb_ctx);

#if defined(__cplusplus)
} /* extern "C" */
#include "exception.h"

static inline void *
smalloc_xc(struct small_alloc *alloc, size_t size, const char *where)
{
	void *ptr = smalloc(alloc, size);
	if (ptr == NULL)
		tnt_raise(OutOfMemory, size, "slab allocator", where);
	return ptr;
}

static inline void *
smalloc0_xc(struct small_alloc *alloc, size_t size, const char *where)
{
	return memset(smalloc_xc(alloc, size, where), 0, size);
}

#endif /* defined(__cplusplus) */

#endif /* INCLUDES_TARANTOOL_SMALL_SMALL_H */
