#!/bin/bash

set -exo pipefail

if [[ ${cuda_compiler_version} != "None" ]]; then
  with_cuda_backend=ON
else
  with_cuda_backend=OFF
fi

if [[ "${target_platform}" == linux* ]]; then
  with_opencl_backend=ON
else
  with_opencl_backend=OFF
fi

if [[ "${target_platform}" == linux-64 ]]; then
  with_rocm_backend=ON
else
  with_rocm_backend=OFF
fi

# Workaround for GCC 14 on AArch64 expanding __arm_* keyword-attributes to [[arm::...]]
# which breaks Clang headers (llvm/llvm-project#78691). Upstream Clang has a fix,
# but undefining these macros at compile time avoids the token-paste error.
# Ref: https://github.com/llvm/llvm-project/issues/78691
#      https://github.com/llvm/llvm-project/pull/78704
if [[ "${target_platform}" == "linux-aarch64" ]]; then
  ACPP_ARM_ATTR_UNDEF="-U__arm_streaming -U__arm_streaming_compatible -U__arm_locally_streaming -U__arm_preserves_za -U__arm_shared_za"
  export CXXFLAGS="${CXXFLAGS} ${ACPP_ARM_ATTR_UNDEF}"
  export CFLAGS="${CFLAGS} ${ACPP_ARM_ATTR_UNDEF}"
fi

cmake \
  $SRC_DIR \
  ${CMAKE_ARGS} \
  -G Ninja \
  -B build \
  -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DWITH_CUDA_BACKEND=$with_cuda_backend \
  -DWITH_OPENCL_BACKEND=$with_opencl_backend \
  -DWITH_ROCM_BACKEND=$with_rocm_backend

cmake --build build --parallel

cmake --install build --strip
