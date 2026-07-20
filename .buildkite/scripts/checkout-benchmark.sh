#!/usr/bin/env bash

set -euo pipefail

strategy="${1:?usage: checkout-benchmark.sh network|mirror [quick|full] [sample-name]}"
profile="${2:-${LLVM_DEMO_CHECKOUT_PROFILE:-quick}}"
sample="${3:-${strategy}}"
repo_url="${LLVM_DEMO_REPO_URL:-https://github.com/pbuckley/llvm-project.git}"
branch="${BUILDKITE_BRANCH:-codex/buildkite-monorepo-demo}"
commit="${BUILDKITE_COMMIT:-HEAD}"
output_root="checkout-benchmark"

case "${strategy}" in
  network|mirror) ;;
  *)
    echo "Unknown checkout strategy: ${strategy}" >&2
    exit 64
    ;;
esac

case "${profile}" in
  quick|full) ;;
  *)
    echo "Unknown checkout profile: ${profile}" >&2
    exit 64
    ;;
esac

case "${sample}" in
  network|eks-mirror) ;;
  *)
    echo "Unknown checkout sample: ${sample}" >&2
    exit 64
    ;;
esac

mkdir -p "${output_root}"
task_root="$(mktemp -d "${TMPDIR:-/tmp}/llvm-checkout-benchmark.XXXXXX")"
trap 'rm -rf -- "${task_root}"' EXIT
destination="${task_root}/llvm-project"
git_log="${output_root}/${sample}-git.log"
metrics_file="${output_root}/${sample}-metrics.json"
summary_file="${output_root}/${sample}-summary.md"
mirror_path="${BUILDKITE_REPO_MIRROR:-}"
mirror_used=false

# Agent Stack runs checkout and command phases in separate containers. The
# checkout phase computes BUILDKITE_REPO_MIRROR locally, while the configured
# mirror root is propagated to every container. Reconstruct the repository
# mirror path using the same non-alphanumeric replacement as Buildkite Agent.
if [[ -z "${mirror_path}" && -n "${BUILDKITE_GIT_MIRRORS_PATH:-}" ]]; then
  mirror_directory_name="$(printf '%s' "${repo_url}" | sed 's/[^[:alnum:]]/-/g')"
  mirror_path="${BUILDKITE_GIT_MIRRORS_PATH}/${mirror_directory_name}"
fi

clone_command=(git clone --no-checkout --progress)
if [[ "${strategy}" == "mirror" ]]; then
  if [[ -z "${mirror_path}" || ! -d "${mirror_path}" ]]; then
    echo "Buildkite did not expose a Git mirror to this job." >&2
    echo "Configure Agent Stack gitMirrors with the EFS-backed PVC." >&2
    exit 69
  fi
  clone_command+=(--reference-if-able "${mirror_path}")
fi

if [[ "${profile}" == "quick" ]]; then
  clone_command+=(--depth=1 --single-branch --branch "${branch}")
fi
clone_command+=("${repo_url}" "${destination}")

echo "--- :git: ${sample} clone (${profile} profile)"
echo "Repository: ${repo_url}"
echo "Target commit: ${commit}"
if [[ "${strategy}" == "mirror" ]]; then
  echo "Buildkite mirror: ${mirror_path}"
fi

clone_start_ns="$(date +%s%N)"
GIT_TERMINAL_PROMPT=0 "${clone_command[@]}" 2>&1 | tee "${git_log}"
clone_end_ns="$(date +%s%N)"
clone_ms="$(( (clone_end_ns - clone_start_ns) / 1000000 ))"

if [[ -s "${destination}/.git/objects/info/alternates" ]]; then
  mirror_used=true
fi

echo "--- :open_file_folder: Materialize the working tree"
checkout_start_ns="$(date +%s%N)"
git -C "${destination}" checkout --detach "${commit}" 2>&1 | tee -a "${git_log}"
checkout_end_ns="$(date +%s%N)"
checkout_ms="$(( (checkout_end_ns - checkout_start_ns) / 1000000 ))"
total_ms="$((clone_ms + checkout_ms))"

local_object_bytes="$(( $(du -sk "${destination}/.git/objects" | awk '{print $1}') * 1024 ))"
working_tree_bytes="$(( $(du -sk --exclude=.git "${destination}" | awk '{print $1}') * 1024 ))"
tracked_files="$(git -C "${destination}" ls-files -z | tr -cd '\0' | wc -c | tr -d ' ')"
mirror_bytes=0
if [[ -n "${mirror_path}" && -d "${mirror_path}" ]]; then
  mirror_bytes="$(( $(du -sk "${mirror_path}" | awk '{print $1}') * 1024 ))"
fi

python3 - "${metrics_file}" "${sample}" "${strategy}" "${profile}" "${clone_ms}" \
  "${checkout_ms}" "${total_ms}" "${local_object_bytes}" \
  "${working_tree_bytes}" "${mirror_bytes}" "${tracked_files}" \
  "${mirror_used}" "${repo_url}" "${commit}" <<'PY'
import json
from pathlib import Path
import sys

(
    output,
    sample,
    clone_strategy,
    profile,
    clone_ms,
    checkout_ms,
    total_ms,
    local_object_bytes,
    working_tree_bytes,
    mirror_bytes,
    tracked_files,
    mirror_used,
    repo_url,
    commit,
) = sys.argv[1:]

metrics = {
    "sample": sample,
    "strategy": clone_strategy,
    "profile": profile,
    "clone_ms": int(clone_ms),
    "checkout_ms": int(checkout_ms),
    "total_ms": int(total_ms),
    "local_object_bytes": int(local_object_bytes),
    "working_tree_bytes": int(working_tree_bytes),
    "mirror_bytes": int(mirror_bytes),
    "tracked_files": int(tracked_files),
    "mirror_used": mirror_used == "true",
    "repository": repo_url,
    "commit": commit,
}
Path(output).write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
PY

cat > "${summary_file}" <<MARKDOWN
### ${sample} checkout sample

- **Profile:** ${profile}
- **Clone/fetch:** $(printf '%d.%03d' "$((clone_ms / 1000))" "$((clone_ms % 1000))")s
- **Working-tree checkout:** $(printf '%d.%03d' "$((checkout_ms / 1000))" "$((checkout_ms % 1000))")s
- **Total measured Git time:** $(printf '%d.%03d' "$((total_ms / 1000))" "$((total_ms % 1000))")s
- **Tracked files:** ${tracked_files}
- **Borrowing from Buildkite mirror:** ${mirror_used}
MARKDOWN

if command -v buildkite-agent >/dev/null 2>&1; then
  buildkite-agent meta-data set "llvm-checkout-${sample}-total-ms" "${total_ms}"
  buildkite-agent annotate --style info --context "llvm-checkout-${sample}" \
    < "${summary_file}"
fi

echo "+++ :white_check_mark: ${sample} checkout benchmark completed in ${total_ms}ms"
