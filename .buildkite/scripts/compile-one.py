#!/usr/bin/env python3

"""Compile one translation unit from a CMake compilation database."""

import json
from pathlib import Path
import shlex
import subprocess
import sys


if len(sys.argv) != 3:
    raise SystemExit("usage: compile-one.py COMPILE_COMMANDS SOURCE")

database_path = Path(sys.argv[1])
source_path = Path(sys.argv[2]).resolve()
database = json.loads(database_path.read_text(encoding="utf-8"))

for entry in database:
    if Path(entry["file"]).resolve() != source_path:
        continue
    command = entry.get("arguments") or shlex.split(entry["command"])
    print("Executing CMake-generated compile command:")
    print(shlex.join(command))
    subprocess.run(command, cwd=entry["directory"], check=True)
    break
else:
    raise SystemExit(f"no compile command found for {source_path}")
