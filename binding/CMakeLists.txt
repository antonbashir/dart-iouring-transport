cmake_minimum_required(VERSION 3.18.0)
project(binding C ASM)

add_definitions("-D_GNU_SOURCE")
set(CMAKE_REQUIRED_DEFINITIONS "-D_GNU_SOURCE")

macro(set_source_files_compile_flags)
  foreach(file ${ARGN})
    get_filename_component(_file_ext ${file} EXT)
    set(_lang "")

    if("${_file_ext}" STREQUAL ".m")
      set(_lang OBJC)

      # CMake believes that Objective C is a flavor of C++, not C,
      # and uses g++ compiler for .m files.
      # LANGUAGE property forces CMake to use CC for ${file}
      set_source_files_properties(${file} PROPERTIES LANGUAGE C)
    elseif("${_file_ext}" STREQUAL ".mm")
      set(_lang OBJCXX)
    endif()

    if(_lang)
      get_source_file_property(_flags ${file} COMPILE_FLAGS)

      if("${_flags}" STREQUAL "NOTFOUND")
        set(_flags "${CMAKE_${_lang}_FLAGS}")
      else()
        set(_flags "${_flags} ${CMAKE_${_lang}_FLAGS}")
      endif()

      # message(STATUS "Set (${file} ${_flags}")
      set_source_files_properties(${file} PROPERTIES COMPILE_FLAGS
        "${_flags}")
    endif()
  endforeach()

  unset(_file_ext)
  unset(_lang)
endmacro(set_source_files_compile_flags)

macro(libev_build)
  set(ev_compile_flags ${DEPENDENCY_CFLAGS})
  set(ev_link_libraries)

  # There are warnings in libev code which are impossible to selectively
  # turn off, see
  # http://gcc.gnu.org/bugzilla/show_bug.cgi?id=45977
  # http://pod.tst.eu/http://cvs.schmorp.de/libev/ev.pod#COMPILER_WARNINGS
  # while this stand off is going on, the world is not a very happy
  # place:
  set(ev_compile_flags "${ev_compile_flags} -w")

  set(ev_compile_flags "${ev_compile_flags} -DENABLE_BUNDLED_LIBEV=1")

  set(ev_compile_flags "${ev_compile_flags} -DEV_USE_INOTIFY")
  set(ev_compile_flags "${ev_compile_flags} -DEV_USE_EVENTFD")
  set(ev_compile_flags "${ev_compile_flags} -DEV_USE_SIGNALFD")
  set(ev_compile_flags "${ev_compile_flags} -DEV_USE_IOURING")
  set(ev_compile_flags "${ev_compile_flags} -DHAVE_LINUX_FS_H")
  set(ev_compile_flags "${ev_compile_flags} -DHAVE_SYS_TIMERFD_H")
  set(ev_compile_flags "${ev_compile_flags} -DHAVE_KERNEL_RWF_T")

  list(APPEND ev_link_libraries "m")

  set(libev_src
    ${PROJECT_SOURCE_DIR}/fiber/fiber_ev.c
  )

  add_library(ev STATIC ${libev_src})

  set_target_properties(ev PROPERTIES COMPILE_FLAGS "${ev_compile_flags}")
  target_link_libraries(ev ${ev_link_libraries})

  set(LIBEV_INCLUDE_DIR ${PROJECT_BINARY_DIR})
  set(LIBEV_LIBRARIES ev)

  unset(ev_src)
  unset(ev_compile_flags)
  unset(ev_link_libraries)
endmacro(libev_build)

macro(libcoro_build)
  set(coro_src
    ${PROJECT_SOURCE_DIR}/coro/coro.c
  )
  set_source_files_properties(${coro_src} PROPERTIES
    COMPILE_FLAGS "${DEPENDENCY_CFLAGS} -fomit-frame-pointer")

  add_library(coro STATIC ${coro_src})

  set(LIBCORO_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/coro)
  set(LIBCORO_LIBRARIES coro)

  if(${CMAKE_SYSTEM_PROCESSOR} MATCHES "86" OR ${CMAKE_SYSTEM_PROCESSOR} MATCHES "amd64")
    add_definitions("-DCORO_ASM")
  elseif(${CMAKE_SYSTEM_PROCESSOR} MATCHES "arm" OR ${CMAKE_SYSTEM_PROCESSOR} MATCHES "aarch64")
    add_definitions("-DCORO_ASM")
  else()
    add_definitions("-DCORO_SJLJ")
  endif()

  unset(coro_src)
endmacro(libcoro_build)

set(LIBURING_VERSION liburing-2.3)
set(CK_VERSION 0.6.0)
set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -O0 -g -fPIC -static-libgcc -static-libstdc++")
set(CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO} -O2 -fPIC -static-libgcc -static-libstdc++")
set(DEPENDENCY_CFLAGS "-fPIC -O2")
set(DEPENDENCY_CPPFLAGS "-fPIC -O2")
set(DEPENDENCY_LDFLAGS)
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}")
set(ENABLE_BUNDLED_LIBEV ON)
set(HAVE_CLOCK_GETTIME_DECL ON)
set(ENABLE_BUNDLED_LIBCORO ON)

include(FetchContent)

FetchContent_Declare(
  ck
  URL https://github.com/concurrencykit/ck/archive/refs/tags/${CK_VERSION}.tar.gz
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/ck
)
FetchContent_MakeAvailable(ck)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/ck/include)

add_custom_target(ck
  COMMAND ./configure
  CC=${CMAKE_C_COMPILER}
  CXX=${CMAKE_CXX_COMPILER}
  CFLAGS=${DEPENDENCY_CFLAGS}
  CPPFLAGS=${DEPENDENCY_CPPFLAGS}
  LDFLAGS=${DEPENDENCY_LDFLAGS}
  --prefix=${CMAKE_CURRENT_SOURCE_DIR}/ck/build && make && make install
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/ck
)

FetchContent_Declare(
  liburing
  URL "https://github.com/axboe/liburing/archive/refs/tags/${LIBURING_VERSION}.tar.gz"
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/liburing
)
FetchContent_MakeAvailable(liburing)
include_directories(${liburing_SOURCE_DIR}/src/include)

add_custom_target(liburing
  COMMAND ./configure
  --prefix=${liburing_SOURCE_DIR}/build && make && make install
  WORKING_DIRECTORY ${liburing_SOURCE_DIR}
)

configure_file(
  "${PROJECT_SOURCE_DIR}/trivia/config.h.cmake"
  "${PROJECT_BINARY_DIR}/trivia/config.h"
)
message(STATUS "")

file(GLOB sources
  *.c
  *.h
  fiber/*.h
  fiber/*.c
  dart/*.h
  dart/*.c
)

include_directories(${PROJECT_BINARY_DIR})
include_directories(${PROJECT_SOURCE_DIR})
include_directories(small/include)
include_directories(small/third_party)
include_directories(fiber)
include_directories(salad)
libev_build()
libcoro_build()

add_subdirectory(small)
add_subdirectory(salad)
add_subdirectory(bit)

add_library(binding SHARED ${sources})
add_dependencies(binding liburing coro ev small ck salad bit)
target_link_libraries(binding PRIVATE ${liburing_SOURCE_DIR}/build/lib/liburing.a ${CMAKE_CURRENT_SOURCE_DIR}/ck/build/lib/libck.a small salad ev bit coro)
add_custom_command(TARGET binding POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:binding> ${CMAKE_CURRENT_SOURCE_DIR}/../dart/native/libtransport.so
)