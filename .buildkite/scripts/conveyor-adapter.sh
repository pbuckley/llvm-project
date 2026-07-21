#!/usr/bin/env bash

set -euo pipefail

action="${1:?usage: conveyor-adapter.sh ACTION COMPONENT}"
component="${2:?usage: conveyor-adapter.sh ACTION COMPONENT}"
release_root="product-release/${component}"
package_root="${release_root}/package"

checksum_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

case "${action}" in
  test)
    echo "--- :conveyor_belt: Existing command contract"
    echo "conveyor test ${component}"
    echo "Buildkite is orchestrating the existing script rather than rewriting it."
    .buildkite/scripts/build-component.sh "${component}"
    ;;

  package)
    manifest="${release_root}/release-manifest.json"
    [[ -f "${manifest}" ]] || { echo "Missing ${manifest}" >&2; exit 66; }
    mkdir -p "${package_root}"
    cp "${manifest}" "${package_root}/release-manifest.json"
    commit="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["commit"])' "${manifest}")"
    cat > "${package_root}/package-metadata.json" <<JSON
{
  "product": "${component}",
  "commit": "${commit}",
  "producer": "conveyor package ${component}",
  "source_build": "${BUILDKITE_BUILD_URL:-local}"
}
JSON
    tar -czf "${package_root}/${component}-${commit:0:12}.tar.gz" \
      -C "${package_root}" release-manifest.json package-metadata.json
    checksum="$(checksum_file "${package_root}/${component}-${commit:0:12}.tar.gz")"
    printf '%s  %s\n' "${checksum}" "${component}-${commit:0:12}.tar.gz" \
      > "${package_root}/SHA256SUMS"
    echo "+++ :package: Packaged immutable ${component} material at ${commit:0:12}"
    ;;

  terraform-plan)
    slice="${BUILDKITE_PARALLEL_JOB:-0}"
    retry_count="${BUILDKITE_RETRY_COUNT:-0}"
    failure_mode="${LLVM_DEMO_FAILURE_MODE:-off}"
    metadata="${package_root}/package-metadata.json"
    [[ -f "${metadata}" ]] || { echo "Missing packaged material" >&2; exit 66; }
    commit="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["commit"])' "${metadata}")"
    echo "--- :terraform: conveyor terraform-plan ${component} --slice ${slice}"
    echo "Using packaged commit ${commit:0:12}; repository checkout intentionally skipped."
    if [[ "${failure_mode}" == "${component}-once" && "${slice}" == "3" && "${retry_count}" == "0" ]]; then
      echo "Intentional demo failure in ${component} slice ${slice}; only this job will retry." >&2
      exit 42
    fi
    mkdir -p "${release_root}/plans"
    cat > "${release_root}/plans/plan-slice-${slice}.json" <<JSON
{
  "product": "${component}",
  "commit": "${commit}",
  "slice": ${slice},
  "retry_count": ${retry_count},
  "result": "planned",
  "repository_checkout": false
}
JSON
    echo "+++ :white_check_mark: Terraform slice ${slice} planned from immutable material"
    ;;

  promote)
    metadata="${package_root}/package-metadata.json"
    [[ -f "${metadata}" ]] || { echo "Missing packaged material" >&2; exit 66; }
    plan_count="$(find "${release_root}/plans" -name 'plan-slice-*.json' -type f | wc -l | tr -d ' ')"
    [[ "${plan_count}" == "5" ]] || { echo "Expected 5 plans, found ${plan_count}" >&2; exit 67; }
    commit="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["commit"])' "${metadata}")"
    cat > "${release_root}/deployment-record.json" <<JSON
{
  "product": "${component}",
  "commit": "${commit}",
  "source_build": "${BUILDKITE_BUILD_URL:-local}",
  "orchestrator_build": "${LLVM_DEMO_PARENT_BUILD_URL:-}",
  "terraform_slices": ${plan_count},
  "result": "promotion-demonstrated",
  "repository_checkout": false
}
JSON
    echo "+++ :rocket: Promoted the same ${component} material at ${commit:0:12}"
    if command -v buildkite-agent >/dev/null 2>&1; then
      buildkite-agent annotate --style success --context "promotion-${component}" <<MARKDOWN
## ${component}: where is my stuff?

The material built from commit **\`${commit:0:12}\`** passed all **${plan_count}**
Terraform slices and reached the promotion step without rebuilding or cloning
the monorepo in any downstream job.

- Product build: ${BUILDKITE_BUILD_URL:-local}
- Monorepo orchestrator: ${LLVM_DEMO_PARENT_BUILD_URL:-direct-build}

### Traceable records

- <a href="artifact://${release_root}/release-manifest.json">Release manifest (JSON)</a>
  and <a href="artifact://${release_root}/release-manifest.md">release manifest (Markdown)</a>
- <a href="artifact://${package_root}/SHA256SUMS">Package checksum</a>
  and <a href="artifact://${package_root}/${component}-${commit:0:12}.tar.gz">immutable package archive</a>
- Terraform plans:
  <a href="artifact://${release_root}/plans/plan-slice-0.json">1/5</a>,
  <a href="artifact://${release_root}/plans/plan-slice-1.json">2/5</a>,
  <a href="artifact://${release_root}/plans/plan-slice-2.json">3/5</a>,
  <a href="artifact://${release_root}/plans/plan-slice-3.json">4/5</a>,
  <a href="artifact://${release_root}/plans/plan-slice-4.json">5/5</a>
- <a href="artifact://${release_root}/deployment-record.json">Deployment record</a>
MARKDOWN
    fi
    ;;

  *)
    echo "Unknown Conveyor adapter action: ${action}" >&2
    exit 64
    ;;
esac
