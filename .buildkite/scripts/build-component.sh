#!/usr/bin/env bash

set -euo pipefail

component="${1:?usage: build-component.sh COMPONENT}"
jobs="${LLVM_DEMO_BUILD_JOBS:-2}"
build_root="${BUILDKITE_BUILD_CHECKOUT_PATH:-${PWD}}/build/demo/${component}"
source_root="llvm"
projects=""
runtimes=""
target=""
compile_source=""
compile_cxx_standard=""
extra_cmake_args=()

case "${component}" in
  llvm)
    target="llvm-config"
    ;;
  clang)
    projects="clang"
    target="clang-tblgen"
    ;;
  lld)
    projects="lld"
    compile_source="lld/Common/Strings.cpp"
    ;;
  runtimes)
    source_root="runtimes"
    runtimes="libcxx;libcxxabi;libunwind"
    compile_source="libcxx/src/algorithm.cpp"
    compile_cxx_standard="c++20"
    ;;
  mlir)
    projects="mlir"
    target="mlir-tblgen"
    ;;
  flang)
    projects="clang;mlir;flang"
    target="FortranParser"
    ;;
  lldb)
    projects="clang;lldb"
    target="lldb-argdumper"
    extra_cmake_args+=(
      -DLLDB_ENABLE_CURSES=OFF
      -DLLDB_ENABLE_LIBEDIT=OFF
      -DLLDB_ENABLE_LUA=OFF
      -DLLDB_ENABLE_PYTHON=OFF
    )
    ;;
  compiler-rt)
    projects="compiler-rt"
    target="builtins"
    ;;
  openmp)
    source_root="runtimes"
    projects=""
    runtimes="openmp"
    target="omp"
    ;;
  bolt)
    projects="bolt"
    target="llvm-bolt-heatmap"
    ;;
  polly)
    projects="polly"
    target="Polly"
    ;;
  *)
    echo "Unknown LLVM demo component: ${component}" >&2
    exit 64
    ;;
esac

if [[ "${LLVM_DEMO_DRY_RUN:-false}" == "true" ]]; then
  printf 'component=%s projects=%s runtimes=%s target=%s source=%s parallel=%s\n' \
    "${component}" "${projects}" "${runtimes}" "${target}" \
    "${compile_source}" "${jobs}"
  exit 0
fi

missing_tools=()
for tool in cmake ninja c++; do
  command -v "${tool}" >/dev/null 2>&1 || missing_tools+=("${tool}")
done

if (( ${#missing_tools[@]} > 0 )); then
  echo "Installing missing build tools: ${missing_tools[*]}"
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "This agent image needs cmake, ninja, and a C++ compiler." >&2
    exit 69
  fi
  sudo_command=()
  if [[ "$(id -u)" != "0" ]]; then
    sudo_command=(sudo -n)
  fi
  "${sudo_command[@]}" apt-get update
  "${sudo_command[@]}" apt-get install -y build-essential cmake ninja-build python3
fi

cmake_args=(
  -S "${source_root}"
  -B "${build_root}"
  -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
  -DLLVM_ENABLE_PROJECTS="${projects}"
  -DLLVM_ENABLE_RUNTIMES="${runtimes}"
  -DLLVM_TARGETS_TO_BUILD=X86
  -DLLVM_ENABLE_ASSERTIONS=ON
  -DLLVM_ENABLE_BINDINGS=OFF
  -DLLVM_ENABLE_LIBXML2=OFF
  -DLLVM_ENABLE_TERMINFO=OFF
  -DLLVM_ENABLE_ZLIB=OFF
  -DLLVM_ENABLE_ZSTD=OFF
  -DLLVM_INCLUDE_BENCHMARKS=OFF
  -DLLVM_INCLUDE_DOCS=OFF
  -DLLVM_INCLUDE_EXAMPLES=OFF
  -DLLVM_INCLUDE_TESTS=OFF
  -DLLVM_PARALLEL_LINK_JOBS=1
)

if command -v clang >/dev/null 2>&1 && command -v clang++ >/dev/null 2>&1; then
  cmake_args+=(
    -DCMAKE_C_COMPILER=clang
    -DCMAKE_CXX_COMPILER=clang++
  )
fi

cmake_args+=("${extra_cmake_args[@]}")

echo "--- :mag: ${component} lane"
echo "Mode: ${LLVM_DEMO_MODE:-fast}"
echo "Target: ${target:-single translation unit}"
echo "Agent CPUs: $(getconf _NPROCESSORS_ONLN 2>/dev/null || echo unknown)"
echo "Build parallelism: ${jobs}"

echo "--- :cmake: Configure"
cmake "${cmake_args[@]}"

if [[ -n "${compile_source}" ]]; then
  echo "--- :hammer: Compile ${compile_source}"
  compile_command=(
    python3 .buildkite/scripts/compile-one.py
    "${build_root}/compile_commands.json" "${compile_source}"
  )
  if [[ -n "${compile_cxx_standard}" ]]; then
    compile_command+=(--cxx-standard "${compile_cxx_standard}")
  fi
  "${compile_command[@]}"
  echo "+++ :white_check_mark: ${component} representative compile passed"
  exit 0
fi

echo "--- :hammer: Build ${target}"
cmake --build "${build_root}" --target "${target}" --parallel "${jobs}"

echo "+++ :white_check_mark: ${component} representative build passed"
