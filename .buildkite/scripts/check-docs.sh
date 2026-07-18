#!/usr/bin/env bash

set -euo pipefail

changed_docs=()
while IFS= read -r path; do
  changed_docs+=("${path}")
done < <(
  .buildkite/scripts/changed-files.sh \
    | awk '/\.(md|rst)$/ { print }'
)

if (( ${#changed_docs[@]} == 0 )); then
  echo "No documentation files were selected."
  exit 0
fi

python3 - "${changed_docs[@]}" <<'PY'
from pathlib import Path
import sys

for value in sys.argv[1:]:
    path = Path(value)
    if not path.is_file():
        raise SystemExit(f"selected documentation path does not exist: {path}")
    path.read_text(encoding="utf-8")
    print(f"UTF-8 OK: {path}")
PY

echo "Documentation integrity checks passed for ${#changed_docs[@]} file(s)."
