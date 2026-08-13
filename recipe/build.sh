#!/bin/bash

set -exo pipefail

if [[ ${cuda_compiler_version} != "None" ]]; then
  with_cuda_backend=ON
else
  with_cuda_backend=OFF
fi

if [[ "${target_platform}" == linux* ]]; then
  with_opencl_backend=ON

  # LLVM 16-18's SmallVector.h relies on a transitive <cstdint> include that
  # GCC 15 no longer provides. Force it in for AdaptiveCpp and the bundled
  # SPIR-V translator; without this, uint32_t/uint64_t are undefined.
  if [[ "${llvm_version}" -le 18 ]]; then
    export CXXFLAGS="${CXXFLAGS} -include cstdint"
  fi
else
  with_opencl_backend=OFF
fi

if [[ "${target_platform}" == linux-64 ]]; then
  with_rocm_backend=ON
else
  with_rocm_backend=OFF
fi

cmake_extra_args=()

if [[ "${target_platform}" == linux* ]]; then
  cmake_extra_args+=("-DACPP_LLD_PATH=${PREFIX}/bin/ld.lld")
  cmake_extra_args+=("-DACPP_OPENCL_HEADERS_SOURCE_DIR=${SRC_DIR}/opencl-headers")
  cmake_extra_args+=("-DACPP_OPENCL_CLHPP_SOURCE_DIR=${SRC_DIR}/opencl-clhpp")
  cmake_extra_args+=("-DACPP_LLVMSPIRV_SOURCE_DIR=${SRC_DIR}/acpp-spirv-llvm-translator")
  cmake_extra_args+=("-DACPP_SPIRV_HEADERS_SOURCE_DIR=${PREFIX}")
  cmake_extra_args+=("-DFETCHCONTENT_FULLY_DISCONNECTED=ON")

  if [[ "${target_platform}" != "${build_platform}" ]]; then
    cmake_extra_args+=("-DACPP_HOST_FORCE_MCPU_TARGET=generic")
  fi

  test -f "${PREFIX}/include/spirv/unified1/spirv.hpp"
  test -f "${SRC_DIR}/opencl-headers/CL/cl.h"
  test -f "${SRC_DIR}/opencl-clhpp/include/CL/opencl.hpp"
  test -f "${SRC_DIR}/acpp-spirv-llvm-translator/CMakeLists.txt"
fi

if [[ "${with_rocm_backend}" == ON ]]; then
  cmake_extra_args+=("-DROCM_PATH=${PREFIX}")
  cmake_extra_args+=("-DROCM_DEVICE_LIBS_PATH=${PREFIX}/lib/amdgcn/bitcode")
fi

if [[ "${with_cuda_backend}" == ON && "${target_platform}" == linux-64 ]]; then
  cmake_extra_args+=("-DCUDA_DEVICE_LIBS_PATH=${PREFIX}/nvvm/libdevice")
  # Link the nvvm device path to the default lookup location of acpp
  mkdir -p "${PREFIX}/lib/hipSYCL/ext/bitcode/ptx"
  ln -sf ../../../../../nvvm/libdevice/libdevice.10.bc \
    "${PREFIX}/lib/hipSYCL/ext/bitcode/ptx/libdevice.10.bc"
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
  -DWITH_ROCM_BACKEND=$with_rocm_backend \
  "${cmake_extra_args[@]}"

cmake --build build --parallel

# AdaptiveCpp's install(CODE) invokes this target from the wrong working
# directory, and ignores the resulting failure. Install the matching patched
# translator explicitly at the path used by the runtime JIT.
if [[ "${target_platform}" == linux* ]]; then
  cmake --build build --target InstallLLVMSpirvTranslator
  test -x "${PREFIX}/lib/hipSYCL/ext/llvm-spirv/bin/llvm-spirv"
fi

cmake --install build --strip

if [[ "${target_platform}" == "osx-64" ]]; then
  # Avoid recording the ephemeral build-env compiler in the new native macOS package.
  sed -i.bak -E \
    "s#\"default-cpu-cxx\"[[:space:]]*:[[:space:]]*\"[^\"]*\"#\"default-cpu-cxx\"   : \"${PREFIX}/bin/clang++\"#" \
    "${PREFIX}/etc/AdaptiveCpp/acpp-core.json"
  rm -f "${PREFIX}/etc/AdaptiveCpp/acpp-core.json.bak"
fi
