cmake_minimum_required(VERSION 3.10)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

project(adaptivecpp-cuda-compile-smoke)

find_package(AdaptiveCpp CONFIG REQUIRED)

add_executable(${PROJECT_NAME} cuda_compile_smoke.cpp)
add_sycl_to_target(TARGET ${PROJECT_NAME} SOURCES cuda_compile_smoke.cpp)
