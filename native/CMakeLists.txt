cmake_minimum_required(VERSION 3.16.0)

project(native C ASM)

include_directories(${liburing_SOURCE_DIR}/src/include)
include_directories(${liburing_BINARY_DIR}/src/include)

include_directories(${PROJECT_BINARY_DIR})
include_directories(${PROJECT_SOURCE_DIR})
include_directories(include)

file(GLOB sources
  *.c
  *.h
  collections/*.h
  collections/*.c
  common/*.h
  common/*.c
)

add_library(transport_debug_linux_x64 SHARED ${sources})
add_dependencies(transport_debug_linux_x64 liburing)
target_link_libraries(transport_debug_linux_x64 PRIVATE ${liburing_SOURCE_DIR}/build/lib/liburing.a)
add_custom_command(TARGET transport_debug_linux_x64 POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:transport_debug_linux_x64> ${CMAKE_CURRENT_SOURCE_DIR}/../dart/native/libtransport_debug_linux_x64.so)

add_library(transport_release_linux_x64 SHARED ${sources})
add_dependencies(transport_release_linux_x64 liburing)
target_link_libraries(transport_release_linux_x64 PRIVATE ${liburing_SOURCE_DIR}/build/lib/liburing.a)
add_custom_command(TARGET transport_release_linux_x64 POST_BUILD COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:transport_release_linux_x64> ${CMAKE_CURRENT_SOURCE_DIR}/../dart/native/libtransport_release_linux_x64.so)

add_custom_target(native DEPENDS transport_release_linux_x64 transport_debug_linux_x64)