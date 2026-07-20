#!/usr/bin/env python3

"""Render the EKS network-versus-EFS-mirror checkout comparison."""

import json
import math
from pathlib import Path
import sys


if len(sys.argv) != 5:
    raise SystemExit(
        "usage: compare-checkouts.py NETWORK_JSON EKS_MIRROR_JSON "
        "OUTPUT_MD OUTPUT_JSON"
    )

network = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
eks_mirror = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
samples = (network, eks_mirror)

if len({sample["profile"] for sample in samples}) != 1:
    raise SystemExit("checkout profiles do not match")
if len({sample["commit"] for sample in samples}) != 1:
    raise SystemExit("checkout commits do not match")
if len({sample["tracked_files"] for sample in samples}) != 1:
    raise SystemExit("tracked file counts do not match")
if not eks_mirror["mirror_used"]:
    raise SystemExit("the EKS mirror sample did not borrow Git objects")


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


def bar_columns(value: int, maximum: int) -> int:
    """Quantize a value onto Buildkite's supported 12-column CSS grid."""
    if value <= 0 or maximum <= 0:
        return 0
    return max(1, min(12, math.ceil(value / maximum * 12)))


def bar_row(label: str, value: int, maximum: int, formatted: str, color: str) -> str:
    columns = bar_columns(value, maximum)
    bar = (
        f'<div class="block col-{columns} {color} py1">&nbsp;</div>'
        if columns
        else ""
    )
    return (
        '<div class="flex items-center mb2">'
        f'<div class="col-3 pr2 right-align bold">{label}</div>'
        '<div class="col-7 bg-muted rounded overflow-hidden">'
        f"{bar}"
        "</div>"
        f'<div class="col-2 pl2 bold">{formatted}</div>'
        "</div>"
    )


network_ms = network["total_ms"]
mirror_ms = eks_mirror["total_ms"]
saved_ms = network_ms - mirror_ms
speedup = network_ms / mirror_ms if mirror_ms else 0
saved_percent = saved_ms / network_ms * 100 if network_ms else 0
object_bytes_avoided = max(
    0, network["local_object_bytes"] - eks_mirror["local_object_bytes"]
)
fanout_agent_minutes_saved = saved_ms * 12 / 60_000
profile_description = (
    "depth-1 snapshot" if network["profile"] == "quick" else "full Git history"
)
runtime_max = max(network_ms, mirror_ms)
objects_max = max(network["local_object_bytes"], eks_mirror["local_object_bytes"])
result_color = "green" if saved_ms >= 0 else "red"
result_background = "bg-green" if saved_ms >= 0 else "bg-red"
saved_label = "checkout time saved" if saved_ms >= 0 else "checkout regression"
fanout_label = "agent-minutes avoided" if saved_ms >= 0 else "extra agent-minutes"
if saved_ms >= 0:
    performance_takeaway = (
        f"**Persistent EFS mirror:** {speedup:.1f}× faster; "
        f"{seconds(saved_ms)} saved ({saved_percent:.1f}%)."
    )
else:
    performance_takeaway = (
        "**Persistent EFS mirror:** "
        f"{seconds(abs(saved_ms))} slower ({abs(saved_percent):.1f}% longer)."
    )

runtime_chart = "".join(
    (
        bar_row(
            "Network only", network_ms, runtime_max, seconds(network_ms), "bg-blue"
        ),
        bar_row(
            "EFS mirror", mirror_ms, runtime_max, seconds(mirror_ms), result_background
        ),
    )
)
objects_chart = "".join(
    (
        bar_row(
            "Network only",
            network["local_object_bytes"],
            objects_max,
            size(network["local_object_bytes"]),
            "bg-blue",
        ),
        bar_row(
            "EFS mirror",
            eks_mirror["local_object_bytes"],
            objects_max,
            size(eks_mirror["local_object_bytes"]),
            "bg-teal",
        ),
    )
)

markdown = f"""## LLVM self-hosted EKS checkout performance lab

Both jobs ran on the `llvm-eks-mirror` queue and materialized commit
`{network['commit'][:12]}` with **{network['tracked_files']:,} tracked files**.
The `{network['profile']}` profile compares delivery of a {profile_description}
from GitHub with a reference clone backed by the persistent EFS Git mirror.

<div class="flex flex-wrap mxn1 mb3"><div class="col-12 sm-col-4 px1 mb1"><div class="border rounded p2 center"><div class="h1 bold {result_color}">{speedup:.1f}×</div><div class="h6 caps muted">network-to-mirror speedup</div></div></div><div class="col-12 sm-col-4 px1 mb1"><div class="border rounded p2 center"><div class="h1 bold {result_color}">{seconds(abs(saved_ms))}</div><div class="h6 caps muted">{saved_label}</div></div></div><div class="col-12 sm-col-4 px1 mb1"><div class="border rounded p2 center"><div class="h1 bold {result_color}">{abs(fanout_agent_minutes_saved):.2f}</div><div class="h6 caps muted">{fanout_label} at 12-way fan-out</div></div></div></div>

### Total Git time

<div class="border rounded p3 mb3"><div class="h6 caps muted center mb2">Same scale across both checkout paths</div>{runtime_chart}</div>

### Job-local Git object footprint

<div class="border rounded p3 mb3"><div class="h6 caps muted center mb2">Smaller is better; shared EFS objects are excluded</div>{objects_chart}</div>

| Checkout path | Clone/fetch | Working-tree checkout | Total Git time | Job-local Git objects | Shared mirror |
| --- | ---: | ---: | ---: | ---: | ---: |
| Self-hosted EKS, network only | {seconds(network['clone_ms'])} | {seconds(network['checkout_ms'])} | **{seconds(network['total_ms'])}** | {size(network['local_object_bytes'])} | not used |
| Self-hosted EKS, EFS mirror | {seconds(eks_mirror['clone_ms'])} | {seconds(eks_mirror['checkout_ms'])} | **{seconds(eks_mirror['total_ms'])}** | {size(eks_mirror['local_object_bytes'])} | {size(eks_mirror['mirror_bytes'])} |

### Prospect takeaway

- {performance_takeaway}
- Both samples use the same Agent Stack controller, EKS worker group, job image, and queue. Mirror use is the controlled variable.
- Buildkite manages mirror creation, updates, and file locking while the customer controls the encrypted EFS file system and PVC lifecycle.
- The mirror avoided approximately **{size(object_bytes_avoided)}** of job-local Git objects.
- Across this demo's 12-way fan-out, the measured result represents approximately **{abs(fanout_agent_minutes_saved):.2f} {fanout_label}** per build.

<details><summary>What this measures</summary>

The stopwatch starts immediately before the controlled `git clone` and stops
after `git checkout` materializes the selected commit. Queueing, agent startup,
native pipeline checkout, and artifact transfer are excluded. The mirror sample
uses Git's `--reference-if-able` object-borrowing mechanism.

</details>
"""

result = {
    "profile": network["profile"],
    "commit": network["commit"],
    "network": network,
    "eks_mirror": {
        "sample": eks_mirror["sample"],
        "total_ms": mirror_ms,
        "saved_ms": saved_ms,
        "saved_percent": saved_percent,
        "speedup": speedup,
        "object_bytes_avoided": object_bytes_avoided,
    },
    "fanout_agent_minutes_saved": fanout_agent_minutes_saved,
}

Path(sys.argv[3]).write_text(markdown, encoding="utf-8")
Path(sys.argv[4]).write_text(
    json.dumps(result, indent=2, allow_nan=False) + "\n", encoding="utf-8"
)
print(markdown)
