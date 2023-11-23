cmake_minimum_required(VERSION 3.18.4)
project(transport C ASM)

if(CMAKE_VERSION VERSION_GREATER_EQUAL "3.24.0")
  cmake_policy(SET CMP0135 NEW)
endif()

add_subdirectory(native)