#!/usr/bin/env bash

set -euo pipefail

mode="${LLVM_DEMO_MODE:-fast}"

if [[ -n "${LLVM_DEMO_CHANGED_PATHS:-}" ]]; then
  echo "Using LLVM_DEMO_CHANGED_PATHS override for this demonstration." >&2
  printf '%s\n' "${LLVM_DEMO_CHANGED_PATHS}" \
    | tr ',' '\n' \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d'
  exit 0
fi

if [[ "${mode}" == "full" ]]; then
  echo "Full mode selected: emitting one representative path for every demo lane." >&2
  cat <<'PATHS'
llvm/lib/IR/Verifier.cpp
clang/lib/Sema/Sema.cpp
lld/Common/DriverDispatcher.cpp
libcxx/CMakeLists.txt
mlir/CMakeLists.txt
flang/CMakeLists.txt
lldb/CMakeLists.txt
compiler-rt/CMakeLists.txt
openmp/CMakeLists.txt
bolt/CMakeLists.txt
polly/CMakeLists.txt
llvm/docs/LangRef.md
PATHS
  exit 0
fi

base_commit="$(.buildkite/scripts/resolve-base-commit.sh)"
head_commit="$(git rev-parse HEAD)"

if [[ "${base_commit}" != "${head_commit}" ]]; then
  echo "Fast mode selected: diffing ${base_commit:0:12}..${head_commit:0:12}." >&2
  git diff --name-only "${base_commit}" "${head_commit}"
else
  echo "No parent commit is available; treating every tracked path as changed." >&2
  git ls-tree -r --name-only HEAD
fi
