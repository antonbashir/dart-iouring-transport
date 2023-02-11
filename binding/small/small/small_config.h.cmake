#ifndef BINDING_SMALL_CONFIG_H_INCLUDED
#define BINDING_SMALL_CONFIG_H_INCLUDED

/*
 * Check for deprecated MAP_ANON.
 */
#cmakedefine BINDING_SMALL_HAVE_MAP_ANON 1
#cmakedefine BINDING_SMALL_HAVE_MAP_ANONYMOUS 1

#if !defined(BINDING_SMALL_HAVE_MAP_ANONYMOUS) && defined(BINDING_SMALL_HAVE_MAP_ANON)
/*
 * MAP_ANON is deprecated, MAP_ANONYMOUS should be used instead.
 * Unfortunately, it's not universally present (e.g. not present
 * on FreeBSD.
 */
# define MAP_ANONYMOUS MAP_ANON
#endif

/*
 * Defined if this platform has madvise(..)
 * and flags we're interested in.
 */
#cmakedefine BINDING_SMALL_HAVE_MADVISE 1
#cmakedefine BINDING_SMALL_HAVE_MADV_DONTDUMP 1

#if defined(BINDING_SMALL_HAVE_MADVISE)	&& \
    defined(BINDING_SMALL_HAVE_MADV_DONTDUMP)
# define BINDING_SMALL_USE_MADVISE 1
#endif

#endif /* BINDING_SMALL_CONFIG_H_INCLUDED */
