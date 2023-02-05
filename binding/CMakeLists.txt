cmake_minimum_required(VERSION 2.8.11)
project(binding)
enable_language(C)

set(LIBURING_VERSION liburing-2.3)
set(CK_VERSION 0.6.0)
set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -O0 -g -fPIC -static-libgcc -static-libstdc++")
set(CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO} -O2 -fPIC -static-libgcc -static-libstdc++")

include(FetchContent)

FetchContent_Declare(
  ck
  URL https://github.com/concurrencykit/ck/archive/refs/tags/${CK_VERSION}.tar.gz
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/ck
)
FetchContent_MakeAvailable(ck)
include_directories(${CMAKE_CURRENT_SOURCE_DIR}/ck/include)

set(DEPENDENCY_CFLAGS "-fPIC -O2")
set(DEPENDENCY_CPPFLAGS "-fPIC -O2")
set(DEPENDENCY_LDFLAGS)
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}")

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

file(GLOB sources
  **/*.c
  **/*.h
  *.c
  *.h
)

add_subdirectory(small)
include_directories(small/include/small)
include_directories(small/third_party)

add_library(binding SHARED ${sources})
add_dependencies(binding liburing small ck)
target_link_libraries(binding PRIVATE ${liburing_SOURCE_DIR}/build/lib/liburing.a small ${CMAKE_CURRENT_SOURCE_DIR}/ck/build/lib/libck.a)
add_custom_command(TARGET binding POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:binding> ${CMAKE_CURRENT_SOURCE_DIR}/../dart/native/libtransport.so
)