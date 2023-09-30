cmake_minimum_required(VERSION 3.16.0)
project(native C ASM)

if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.24.0")
  cmake_policy(SET CMP0135 NEW)
endif()

add_definitions("-D_GNU_SOURCE")
set(CMAKE_REQUIRED_DEFINITIONS "-D_GNU_SOURCE")

set(LIBURING_VERSION liburing-2.4)
set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -O0 -g -fPIC -static-libgcc -static-libstdc++ -fno-stack-protector")
set(CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO} -O2 -fPIC -static-libgcc -static-libstdc++ -fno-stack-protector")
set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS}")
set(HAVE_CLOCK_GETTIME_DECL ON)

include(FetchContent)

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
  "${PROJECT_SOURCE_DIR}/trivia/config.h"
)
message(STATUS "")

file(GLOB sources
  *.c
  *.h
  dart/*.h
  dart/*.c
  salad/*.h
  salad/*.c
)

include_directories(${PROJECT_BINARY_DIR})
include_directories(${PROJECT_SOURCE_DIR})

add_library(native SHARED ${sources})
add_dependencies(native liburing)
target_link_libraries(native PRIVATE ${liburing_SOURCE_DIR}/build/lib/liburing.a)
add_custom_command(TARGET native POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:native> ${CMAKE_CURRENT_SOURCE_DIR}/../dart/native/libtransport.so
)