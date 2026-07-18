#!/usr/bin/env bash

set -euo pipefail

mode="${LLVM_DEMO_MODE:-fast}"
selected_paths="$(.buildkite/scripts/changed-files.sh)"
path_count="$(printf '%s\n' "${selected_paths}" | sed '/^$/d' | wc -l | tr -d ' ')"
agent_cpus="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo unknown)"

echo "--- :clipboard: Selection plan"
echo "Mode: ${mode}"
echo "Selected paths: ${path_count}"
printf '%s\n' "${selected_paths}"
echo "Detector agent CPUs: ${agent_cpus}"
echo "Build lanes are capped at four concurrent jobs."

if command -v buildkite-agent >/dev/null 2>&1; then
  buildkite-agent meta-data set "llvm-demo-mode-resolved" "${mode}"
  buildkite-agent meta-data set "llvm-demo-selected-path-count" "${path_count}"
  buildkite-agent annotate --style info --context "llvm-demo-plan" <<MARKDOWN
### LLVM monorepo demo plan

- **Mode:** ${mode}
- **Selected paths:** ${path_count}
- **Build-lane concurrency cap:** 4 jobs
- **Detector shape observed:** ${agent_cpus} vCPU

The `monorepo-diff#v1.11.0` plugin generated the project lanes from this selection.
MARKDOWN
fi
