#!/usr/bin/env bash

set -euo pipefail

if [[ "${BUILDKITE_PULL_REQUEST:-false}" != "false" ]]; then
  base_branch="${BUILDKITE_PULL_REQUEST_BASE_BRANCH:-main}"
  echo "Resolving merge base against origin/${base_branch}." >&2
  git fetch --quiet --no-tags origin "${base_branch}"
  git merge-base FETCH_HEAD HEAD
  exit 0
fi

if ! git rev-parse --verify --quiet HEAD^ >/dev/null; then
  branch="${BUILDKITE_BRANCH:-main}"
  git fetch --quiet --no-tags --deepen=2 origin "${branch}" || true
fi

if git rev-parse --verify --quiet HEAD^ >/dev/null; then
  git rev-parse HEAD^
else
  git rev-parse HEAD
fi
