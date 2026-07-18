#!/usr/bin/env python3

"""Render the prospect-facing uncached-versus-mirror checkout comparison."""

import json
from pathlib import Path
import sys


if len(sys.argv) != 5:
    raise SystemExit(
        "usage: compare-checkouts.py NETWORK_JSON MIRROR_JSON OUTPUT_MD OUTPUT_JSON"
    )

network = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
mirror = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
if network["profile"] != mirror["profile"]:
    raise SystemExit("checkout profiles do not match")

network_ms = network["total_ms"]
mirror_ms = mirror["total_ms"]
saved_ms = network_ms - mirror_ms
speedup = network_ms / mirror_ms if mirror_ms else float("inf")
saved_percent = saved_ms / network_ms * 100 if network_ms else 0
object_bytes_avoided = max(
    0, network["local_object_bytes"] - mirror["local_object_bytes"]
)
fanout_agent_minutes_saved = saved_ms * 12 / 60_000
fanout_cost_saved = fanout_agent_minutes_saved * 0.008


def seconds(milliseconds: int) -> str:
    return f"{milliseconds / 1000:.3f}s"


def size(value: int) -> str:
    units = ("B", "KiB", "MiB", "GiB", "TiB")
    amount = float(value)
    for unit in units:
        if amount < 1024 or unit == units[-1]:
            return f"{amount:.2f} {unit}"
        amount /= 1024
    raise AssertionError("unreachable")


profile_description = (
    "depth-1 snapshot" if network["profile"] == "quick" else "full Git history"
)
markdown = f"""## LLVM checkout performance lab

Both jobs materialized the same **{size(network['working_tree_bytes'])}** working
tree with **{network['tracked_files']:,} tracked files**. The `{network['profile']}`
profile compares delivery of a {profile_description} from GitHub with a checkout
that borrows objects from Buildkite's attached **{size(mirror['mirror_bytes'])}**
Git mirror volume.

| Strategy | Clone/fetch | Working-tree checkout | Total Git time | Local Git objects |
| --- | ---: | ---: | ---: | ---: |
| Network, no local cache | {seconds(network['clone_ms'])} | {seconds(network['checkout_ms'])} | **{seconds(network_ms)}** | {size(network['local_object_bytes'])} |
| Buildkite Git mirror | {seconds(mirror['clone_ms'])} | {seconds(mirror['checkout_ms'])} | **{seconds(mirror_ms)}** | {size(mirror['local_object_bytes'])} |

### Prospect takeaway

- **{speedup:.1f}× faster** measured Git delivery; **{seconds(saved_ms)} saved ({saved_percent:.1f}%)** per checkout.
- **{size(object_bytes_avoided)} less job-local Git object storage** because the checkout borrows from the shared mirror.
- Across this demo's 12-way fan-out, that is approximately **{fanout_agent_minutes_saved:.2f} agent-minutes** and **${fanout_cost_saved:.3f}** avoided per build at the current Small Linux Hosted Agent rate.
- Buildkite manages mirror locking and uses best-effort, cluster-scoped NVMe cache volumes; a cache miss safely falls back to the remote repository.

<details><summary>What this measures</summary>

The stopwatch starts immediately before `git clone` and stops after `git
checkout` materializes the selected commit. Queueing, agent startup, artifact
download, and the benchmark jobs' identical native checkouts are excluded.
The mirror sample uses Git's `--reference-if-able`, the same object-borrowing
mechanism used by Buildkite Git mirrors.

</details>
"""

comparison = {
    "profile": network["profile"],
    "network_total_ms": network_ms,
    "mirror_total_ms": mirror_ms,
    "saved_ms": saved_ms,
    "saved_percent": saved_percent,
    "speedup": speedup,
    "object_bytes_avoided": object_bytes_avoided,
    "fanout_agent_minutes_saved": fanout_agent_minutes_saved,
    "fanout_cost_saved_usd": fanout_cost_saved,
}

Path(sys.argv[3]).write_text(markdown, encoding="utf-8")
Path(sys.argv[4]).write_text(
    json.dumps(comparison, indent=2) + "\n", encoding="utf-8"
)
print(markdown)
