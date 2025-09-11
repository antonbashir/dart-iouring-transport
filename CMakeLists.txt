cmake_minimum_required(VERSION 3.16.0)
project(root C ASM)

add_definitions("-D_GNU_SOURCE")
set(EXECUTABLE_OUTPUT_PATH  "${CMAKE_BINARY_DIR}/bin")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED true)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED true)

set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -fPIC -O0 -g -fno-stack-protector")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -fPIC -O0 -g -fno-stack-protector")

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fPIC -O2 -fno-stack-protector")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fPIC -O2 -fno-stack-protector")

set(LIBURING_REPOSITORY "https://github.com/axboe/liburing")
set(LIBURING_VERSION master)

include(FetchContent)

FetchContent_Declare(
  liburing
  GIT_REPOSITORY ${LIBURING_REPOSITORY}
  GIT_TAG ${LIBURING_VERSION}
  SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/dependencies/liburing
)
FetchContent_MakeAvailable(liburing)
add_custom_target(liburing COMMAND ./configure --prefix=${liburing_SOURCE_DIR}/build && make && make install WORKING_DIRECTORY ${liburing_SOURCE_DIR})

add_subdirectory(native)