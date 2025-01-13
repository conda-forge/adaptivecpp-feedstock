#!/bin/bash

set -exo pipefail

if [[ ${cuda_compiler_version} != "None" ]]; then
  with_cuda_backend=ON
else
  with_cuda_backend=OFF
fi

cmake \
  $SRC_DIR \
  ${CMAKE_ARGS} \
  -G Ninja \
  -B build \
  -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_CUDA_BACKEND=$with_cuda_backend \
  -DWITH_OPENCL_BACKEND=OFF \
  -DWITH_ROCM_BACKEND=OFF

cmake --build build --parallel

cmake --install build --strip
