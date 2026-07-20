#!/usr/bin/env bash

set -euo pipefail

for script in .buildkite/scripts/*.sh; do
  bash -n "${script}"
done

for script in .buildkite/scripts/*.py; do
  python3 -m py_compile "${script}"
done

if command -v buildkite-agent >/dev/null 2>&1; then
  buildkite-agent pipeline upload --dry-run .buildkite/pipeline.yml >/dev/null
  buildkite-agent pipeline upload --dry-run .buildkite/checkout-lab.yml >/dev/null
  buildkite-agent pipeline upload --dry-run .buildkite/eks-mirror-bootstrap.yml >/dev/null
elif command -v bk >/dev/null 2>&1; then
  bk pipeline validate \
    --file .buildkite/pipeline.yml \
    --file .buildkite/checkout-lab.yml \
    --file .buildkite/eks-mirror-bootstrap.yml
else
  echo "Shell syntax passed; no Buildkite validator is installed on this machine."
fi

echo "Pipeline integrity checks passed."
