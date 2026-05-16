#!/bin/bash

set -exo pipefail

cmake_extra_args=()

if [[ "${target_platform}" == "osx-64" ]]; then
  cmake_extra_args+=("-DACPP_TARGETS=omp")
  cmake_extra_args+=("-DACPP_CPU_CXX=${CXX}")
fi

cmake tests \
    ${CMAKE_ARGS} \
    -G Ninja \
    -B tests/build \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_BUILD_TYPE=Release \
    "${cmake_extra_args[@]}"

cmake --build tests/build --parallel
