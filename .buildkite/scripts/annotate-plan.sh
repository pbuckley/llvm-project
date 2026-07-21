#!/usr/bin/env bash

set -euo pipefail

mode="${LLVM_DEMO_MODE:-fast}"
topology="${LLVM_DEMO_TOPOLOGY:-build-lanes}"
selected_paths="$(.buildkite/scripts/changed-files.sh)"
path_count="$(printf '%s\n' "${selected_paths}" | sed '/^$/d' | wc -l | tr -d ' ')"
agent_cpus="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo unknown)"
base_commit="${LLVM_DEMO_BASE_COMMIT:-$(.buildkite/scripts/resolve-base-commit.sh)}"
head_commit="$(git rev-parse HEAD)"

selected_products="$({
  while IFS= read -r path; do
    case "${path}" in
      llvm/docs/*|clang/docs/*|clang-tools-extra/docs/*|lld/docs/*|libcxx/docs/*|mlir/docs/*|flang/docs/*|lldb/docs/*|openmp/docs/*|bolt/docs/*|polly/docs/*|*.md|*.rst)
        ;;
      llvm/*) echo "llvm" ;;
      clang/*|clang-tools-extra/*) echo "clang" ;;
      lld/*) echo "lld" ;;
      libcxx/*|libcxxabi/*|libunwind/*|runtimes/*) echo "runtimes" ;;
      mlir/*) echo "mlir" ;;
      flang/*) echo "flang" ;;
      lldb/*) echo "lldb" ;;
      compiler-rt/*) echo "compiler-rt" ;;
      openmp/*|offload/*) echo "openmp" ;;
      bolt/*) echo "bolt" ;;
      polly/*) echo "polly" ;;
      .buildkite/*) ;;
    esac
  done <<< "${selected_paths}"
} | sed '/^$/d' | sort -u)"
product_count="$(printf '%s\n' "${selected_products}" | sed '/^$/d' | wc -l | tr -d ' ')"
product_list="$(printf '%s\n' "${selected_products}" | awk 'NF { printf "%s`%s`", separator, $0; separator=", " }')"
[[ -n "${product_list}" ]] || product_list="none"

echo "--- :clipboard: Selection plan"
echo "Mode: ${mode}"
echo "Topology: ${topology}"
echo "Selected paths: ${path_count}"
echo "Selected products: ${product_count} (${product_list})"
printf '%s\n' "${selected_paths}"
echo "Detector agent CPUs: ${agent_cpus}"
echo "Build lanes use natural parallelism when Hosted Agent capacity permits."

if command -v buildkite-agent >/dev/null 2>&1; then
  buildkite-agent meta-data set "llvm-demo-mode-resolved" "${mode}"
  buildkite-agent meta-data set "llvm-demo-topology-resolved" "${topology}"
  buildkite-agent meta-data set "llvm-demo-selected-path-count" "${path_count}"
  buildkite-agent annotate --style info --context "llvm-demo-plan" <<MARKDOWN
### LLVM monorepo demo plan

- **Mode:** ${mode}
- **Topology:** ${topology}
- **Material:** \`${base_commit:0:12}..${head_commit:0:12}\`
- **Selected paths:** ${path_count}
- **Routed products:** ${product_count} (${product_list})
- **Build-lane scheduling:** natural parallelism
- **Detector shape observed:** ${agent_cpus} vCPU

The `monorepo-diff#v1.11.0` plugin generated the work from this selection.
In product-pipeline mode, every affected folder gets independent build history,
its own scoped changelog, and a release manifest that follows the material
through package, Terraform planning, and promotion.

<details><summary>Changed paths evaluated by the router</summary>

\`\`\`text
${selected_paths}
\`\`\`

</details>
MARKDOWN
fi
