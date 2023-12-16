#ifndef INTERACTOR_COMMON_H_INCLUDED
#define INTERACTOR_COMMON_H_INCLUDED

#if defined(__cplusplus)
extern "C"
{
#endif

#define restrict __restrict__

#ifndef __has_feature
#define __has_feature(x) 0
#endif

#ifndef __has_builtin
#define __has_builtin(x) 0
#endif

#ifndef __has_attribute
#define __has_attribute(x) 0
#endif

#ifndef __has_cpp_attribute
#define __has_cpp_attribute(x) 0
#endif

#if __has_builtin(__builtin_expect) || defined(__GNUC__)
#define likely(x) __builtin_expect(!!(x), 1)
#define unlikely(x) __builtin_expect(!!(x), 0)
#else
#define likely(x) (x)
#define unlikely(x) (x)
#endif

#if __has_builtin(__builtin_prefetch) || defined(__GNUC__)
#define prefetch(addr, ...) (__builtin_prefetch(addr, __VA_ARGS__))
#else
#define prefetch(addr, ...) ((void)addr)
#endif

#if __has_builtin(__builtin_unreachable) || defined(__GNUC__)
#define unreachable() (assert(0), __builtin_unreachable())
#else
#define unreachable() (assert(0))
#endif

#ifndef offset_of
#define offset_of(type, member) ((size_t) & ((type*)0)->member)
#endif

#ifndef container_of
#define container_of(ptr, type, member) ({ \
	const typeof( ((type *)0)->member  ) *__mptr = (ptr); \
	(type *)( (char *)__mptr - offsetof(type,member)  ); })
#endif

#if defined(__cplusplus)
#include <stdalign.h>
#endif
#if !defined(alignas) && !defined(__alignas_is_defined)
#if __has_feature(c_alignas) || (defined(__GNUC__) && __GNUC__ >= 5)
#include <stdalign.h>
#elif __has_attribute(aligned) || defined(__GNUC__)
#define alignas(_n) __attribute__((aligned(_n)))
#define __alignas_is_defined 1
#else
#define alignas(_n)
#endif
#endif

#if !defined(alignof) && !defined(__alignof_is_defined)
#if __has_feature(c_alignof) || (defined(__GNUC__) && __GNUC__ >= 5)
#include <stdalign.h>
#elif defined(__GNUC__)
#define alignof(_T) __alignof(_T)
#define __alignof_is_defined 1
#else
#define alignof(_T) offsetof( \
    struct { char c; _T member; }, member)
#define __alignof_is_defined 1
#endif
#endif

#if defined(__cplusplus) && __has_cpp_attribute(maybe_unused)
#define MAYBE_UNUSED [[maybe_unused]]
#elif __has_attribute(unused) || defined(__GNUC__)
#define MAYBE_UNUSED __attribute__((unused))
#else
#define MAYBE_UNUSED
#endif

#if defined(__cplusplus) && __has_cpp_attribute(nodiscard)
#define NODISCARD [[nodiscard]]
#elif __has_attribute(warn_unused_result) || defined(__GNUC__)
#define NODISCARD __attribute__((warn_unused_result))
#else
#define NODISCARD
#endif

#if __has_attribute(noinline) || defined(__GNUC__)
#define NOINLINE __attribute__((noinline))
#else
#define NOINLINE
#endif

#if defined(__cplusplus) && __has_cpp_attribute(noreturn)
#define NORETURN [[noreturn]]
#elif __has_attribute(noreturn) || defined(__GNUC__)
#define NORETURN __attribute__((noreturn))
#else
#define NORETURN
#endif

#if defined(__cplusplus) && __has_cpp_attribute(deprecated)
#define DEPRECATED(_msg) [[deprecated(_msg)]]
#elif __has_attribute(deprecated) || defined(__GNUC__)
#define DEPRECATED __attribute__((deprecated(_msg)))
#else
#define DEPRECATED(_msg)
#endif

#if defined(__cplusplus) && defined(__GNUC__)
#define API_EXPORT extern "C" __attribute__((nothrow, visibility("default")))
#elif defined(__cplusplus)
#define API_EXPORT extern "C"
#elif defined(__GNUC__)
#define API_EXPORT extern __attribute__((nothrow, visibility("default")))
#else
#define API_EXPORT extern
#endif

#if __has_attribute(format) || defined(__GNUC__)
#define CFORMAT(_archetype, _stringindex, _firsttocheck) \
    __attribute__((format(_archetype, _stringindex, _firsttocheck)))
#else
#define CFORMAT(archetype, stringindex, firsttocheck)
#endif

#if __has_attribute(packed) || defined(__GNUC__)
#define PACKED __attribute__((packed))
#elif defined(__CC_ARM)
#define PACKED __packed
#else
#define PACKED
#endif

#if defined(__cplusplus) && __has_cpp_attribute(fallthrough)
#define FALLTHROUGH [[fallthrough]]
#elif __has_attribute(fallthrough) || (defined(__GNUC__) && __GNUC__ >= 7)
#define FALLTHROUGH __attribute__((fallthrough))
#else
#define FALLTHROUGH
#endif

#include <sys/time.h>
#define CLOCK_REALTIME 0
#define CLOCK_MONOTONIC 1
#define CLOCK_PROCESS_CPUTIME_ID 2
#define CLOCK_THREAD_CPUTIME_ID 3

#if !defined(__cplusplus) && !defined(static_assert)
#define static_assert _Static_assert
#endif

#if defined(__cplusplus)
}
#endif

#endif