#!/usr/bin/env bash

set -euo pipefail

mode="${LLVM_DEMO_MODE:-fast}"
checkout_profile="${LLVM_DEMO_CHECKOUT_PROFILE:-off}"
selected_paths="$(.buildkite/scripts/changed-files.sh)"
path_count="$(printf '%s\n' "${selected_paths}" | sed '/^$/d' | wc -l | tr -d ' ')"
agent_cpus="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo unknown)"

echo "--- :clipboard: Selection plan"
echo "Mode: ${mode}"
echo "Selected paths: ${path_count}"
echo "Checkout lab: ${checkout_profile}"
printf '%s\n' "${selected_paths}"
echo "Detector agent CPUs: ${agent_cpus}"
echo "Build lanes use natural parallelism when Hosted Agent capacity permits."

if command -v buildkite-agent >/dev/null 2>&1; then
  buildkite-agent meta-data set "llvm-demo-mode-resolved" "${mode}"
  buildkite-agent meta-data set "llvm-demo-selected-path-count" "${path_count}"
  buildkite-agent annotate --style info --context "llvm-demo-plan" <<MARKDOWN
### LLVM monorepo demo plan

- **Mode:** ${mode}
- **Selected paths:** ${path_count}
- **Checkout performance lab:** ${checkout_profile}
- **Build-lane scheduling:** natural parallelism
- **Detector shape observed:** ${agent_cpus} vCPU

The `monorepo-diff#v1.11.0` plugin generated the project lanes from this selection.
MARKDOWN
fi
