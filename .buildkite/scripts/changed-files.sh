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

if [[ "${BUILDKITE_PULL_REQUEST:-false}" != "false" ]]; then
  base_branch="${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-main}"
  echo "Diffing pull request against origin/${base_branch}." >&2
  git fetch --quiet --no-tags origin "${base_branch}"
  git diff --name-only "FETCH_HEAD...HEAD"
  exit 0
fi

if ! git rev-parse --verify --quiet HEAD^ >/dev/null; then
  branch="${BUILDKITE_BRANCH:-main}"
  git fetch --quiet --no-tags --deepen=2 origin "${branch}" || true
fi

if git rev-parse --verify --quiet HEAD^ >/dev/null; then
  echo "Fast mode selected: diffing the current commit against its first parent." >&2
  git diff --name-only HEAD^ HEAD
else
  echo "No parent commit is available; treating every tracked path as changed." >&2
  git ls-tree -r --name-only HEAD
fi
