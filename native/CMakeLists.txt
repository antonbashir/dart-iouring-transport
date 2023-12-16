cmake_minimum_required(VERSION 3.18.4)
project(native C ASM)

set(LIBURING_REPOSITORY "developer@git.local:dependencies/liburing.git")
set(LIBURING_VERSION evolution)

add_definitions("-D_GNU_SOURCE")
set(CMAKE_REQUIRED_DEFINITIONS "-D_GNU_SOURCE")
set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -fPIC -O0 -g -fno-stack-protector")
set(CMAKE_C_FLAGS_RELWITHDEBINFO "${CMAKE_C_FLAGS_RELWITHDEBINFO} -fPIC -O3 -fno-stack-protector")
set(HAVE_CLOCK_GETTIME_DECL ON)

include(FetchContent)

FetchContent_Declare(
  liburing
  GIT_REPOSITORY ${LIBURING_REPOSITORY}
  GIT_TAG ${LIBURING_VERSION}
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/liburing
)
FetchContent_MakeAvailable(liburing)
include_directories(${liburing_SOURCE_DIR}/src/include)
add_custom_target(liburing COMMAND ./configure --prefix=${liburing_SOURCE_DIR}/build && make && make install WORKING_DIRECTORY ${liburing_SOURCE_DIR})

include_directories(${PROJECT_BINARY_DIR})
include_directories(${PROJECT_SOURCE_DIR})

file(GLOB sources
  *.c
  *.h
  dart/*.h
  dart/*.c
  collections/*.h
  collections/*.c
)

add_library(native SHARED ${sources})
add_dependencies(native liburing)
target_link_libraries(native PRIVATE ${liburing_SOURCE_DIR}/build/lib/liburing.a)
add_custom_command(TARGET native POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:native> ${CMAKE_CURRENT_SOURCE_DIR}/../dart/native/libtransport.so)