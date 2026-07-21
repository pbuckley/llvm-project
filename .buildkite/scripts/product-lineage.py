#!/usr/bin/env python3

"""Create a product-scoped changelog and immutable release manifest."""

from __future__ import annotations

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


PRODUCT_PATHS = {
    "llvm": (["llvm"], ["llvm/docs/"]),
    "clang": (["clang", "clang-tools-extra"], ["clang/docs/", "clang-tools-extra/docs/"]),
    "lld": (["lld"], ["lld/docs/"]),
    "runtimes": (["libcxx", "libcxxabi", "libunwind", "runtimes"], ["libcxx/docs/"]),
    "mlir": (["mlir"], ["mlir/docs/"]),
    "flang": (["flang"], ["flang/docs/"]),
    "lldb": (["lldb"], ["lldb/docs/"]),
    "compiler-rt": (["compiler-rt"], []),
    "openmp": (["openmp", "offload"], ["openmp/docs/"]),
    "bolt": (["bolt"], ["bolt/docs/"]),
    "polly": (["polly"], ["polly/docs/"]),
}


def git(*args: str, check: bool = True) -> str:
    completed = subprocess.run(
        ["git", *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return completed.stdout.strip()


def ensure_commit(commit: str) -> None:
    if subprocess.run(
        ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0:
        return
    subprocess.run(
        ["git", "fetch", "--quiet", "--no-tags", "--depth=1", "origin", commit],
        check=True,
    )


def github_repository() -> str:
    configured = os.getenv("LLVM_DEMO_REPOSITORY_WEB")
    if configured:
        return configured.rstrip("/")
    remote = git("remote", "get-url", "origin", check=False)
    remote = remote.removesuffix(".git")
    if remote.startswith("git@github.com:"):
        return "https://github.com/" + remote.removeprefix("git@github.com:")
    return remote


def escaped(value: str) -> str:
    return value.replace("|", "\\|").replace("\n", " ")


if len(sys.argv) != 2 or sys.argv[1] not in PRODUCT_PATHS:
    choices = ", ".join(PRODUCT_PATHS)
    raise SystemExit(f"usage: product-lineage.py COMPONENT ({choices})")

component = sys.argv[1]
includes, excludes = PRODUCT_PATHS[component]
head = os.getenv("BUILDKITE_COMMIT", "HEAD")
if head == "HEAD":
    head = git("rev-parse", "HEAD")
base = os.getenv("LLVM_DEMO_BASE_COMMIT") or git("rev-parse", "HEAD^")
ensure_commit(head)
ensure_commit(base)

diff_output = git("diff", "--name-status", base, head, "--", *includes)
files = []
for line in diff_output.splitlines():
    if not line:
        continue
    status, _, path = line.partition("\t")
    if any(path.startswith(prefix) for prefix in excludes):
        continue
    files.append({"status": status, "path": path})

log_format = "%H%x1f%h%x1f%an%x1f%aI%x1f%s"
log_output = git("log", f"--format={log_format}", f"{base}..{head}", "--", *includes)
commits = []
for line in log_output.splitlines():
    if not line:
        continue
    full_sha, short_sha, author, authored_at, subject = line.split("\x1f", 4)
    commits.append(
        {
            "sha": full_sha,
            "short_sha": short_sha,
            "author": author,
            "authored_at": authored_at,
            "subject": subject,
        }
    )

repository = github_repository()
output_dir = Path("product-release") / component
output_dir.mkdir(parents=True, exist_ok=True)
manifest_path = output_dir / "release-manifest.json"
markdown_path = output_dir / "release-manifest.md"
manifest = {
    "schema_version": 1,
    "product": component,
    "base_commit": base,
    "commit": head,
    "repository": repository,
    "parent_build_url": os.getenv("LLVM_DEMO_PARENT_BUILD_URL", ""),
    "product_build_url": os.getenv("BUILDKITE_BUILD_URL", ""),
    "changed_files": files,
    "commits": commits,
}
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

commit_rows = "\n".join(
    f"| [`{entry['short_sha']}`]({repository}/commit/{entry['sha']}) | "
    f"{escaped(entry['subject'])} | {escaped(entry['author'])} |"
    for entry in commits
) or "| — | No product-scoped commits in the selected range | — |"
file_rows = "\n".join(
    f"| `{escaped(entry['status'])}` | `{escaped(entry['path'])}` |" for entry in files
) or "| — | No direct file changes; this product was selected by the full fan-out scenario. |"
parent_link = os.getenv("LLVM_DEMO_PARENT_BUILD_URL", "")
parent_line = f"[Open the monorepo orchestrator]({parent_link})" if parent_link else "Direct product build"

markdown = f"""## {component} product release lineage

| Material | Value |
| --- | --- |
| Product | **`{component}`** |
| Immutable commit | [`{head[:12]}`]({repository}/commit/{head}) |
| Compared with | [`{base[:12]}`]({repository}/commit/{base}) |
| Product-scoped files | **{len(files)}** |
| Product-scoped commits | **{len(commits)}** |
| Orchestration | {parent_line} |

### Changelog for this product

| Commit | Change | Author |
| --- | --- | --- |
{commit_rows}

### Files entering this release

| Status | Path |
| --- | --- |
{file_rows}

The <a href="artifact://{manifest_path.as_posix()}">JSON release manifest</a>
and <a href="artifact://{markdown_path.as_posix()}">Markdown release manifest</a>
are uploaded as immutable artifacts. Downstream Terraform slices and promotion
consume the packaged material without cloning the monorepo again.
"""
markdown_path.write_text(markdown, encoding="utf-8")
print(markdown)

if shutil_path := shutil.which("buildkite-agent"):
    subprocess.run(
        [
            shutil_path,
            "artifact",
            "upload",
            f"{manifest_path};{markdown_path}",
        ],
        check=True,
    )
    subprocess.run(
        [shutil_path, "annotate", "--style", "info", "--context", f"lineage-{component}"],
        input=markdown,
        text=True,
        check=True,
    )
