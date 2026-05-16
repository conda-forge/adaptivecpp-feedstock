@echo on

if "%cuda_compiler_version%" == "None" (
  set with_cuda_backend=OFF
) else (
  set with_cuda_backend=ON
)

cmake %SRC_DIR% ^
  %CMAKE_ARGS% ^
  -T ClangCL ^
  -A x64 ^
  -B build ^
  -DBUILD_SHARED_LIBS=ON ^
  -DWITH_CUDA_BACKEND=%with_cuda_backend% ^
  -DWITH_OPENCL_BACKEND=OFF ^
  -DWITH_ROCM_BACKEND=OFF
if errorlevel 1 exit 1

cmake --build build --parallel --config Release
if errorlevel 1 exit 1

cmake --install build --config Release
if errorlevel 1 exit 1
