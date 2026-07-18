# LLVM monorepo Buildkite demo

This private demo shows how Buildkite can keep a large monorepo pipeline small:
one repository pipeline discovers the changed paths, and
`monorepo-diff#v1.11.0` dynamically uploads only the affected project lanes.

## Running the demo

Use **New Build** in the `LLVM Monorepo Demo` pipeline. The first form offers:

- **Fast — changed projects only (default):** compares the selected commit to
  its first parent and creates only matching lanes.
- **Full — all project lanes:** emits one representative path for every lane,
  creating all 11 code-build lanes plus documentation integrity.

For a repeatable talk-track scenario, set the build environment variable
`LLVM_DEMO_CHANGED_PATHS` to comma-separated paths. For example:

```text
llvm/lib/IR/Verifier.cpp,clang/lib/Sema/Sema.cpp,lld/Common/DriverDispatcher.cpp
```

This override affects project selection only; each generated lane still checks
out and builds the real LLVM source at the chosen commit.

## Path map and representative targets

| Lane | Watched roots | Representative target |
| --- | --- | --- |
| LLVM core | `llvm/` (excluding docs) | `llvm-config` |
| Clang | `clang/`, `clang-tools-extra/` | `clang-tblgen` |
| LLD | `lld/` | `Strings.cpp` translation unit |
| C++ runtimes | `libcxx/`, `libcxxabi/`, `libunwind/`, `runtimes/` | generated libc++ headers |
| MLIR | `mlir/` | `mlir-tblgen` |
| Flang | `flang/` | `default-kinds.cpp` translation unit |
| LLDB | `lldb/` | `lldb-argdumper` |
| compiler-rt | `compiler-rt/` | `builtins` |
| OpenMP/offload | `openmp/`, `offload/` | `omp` |
| BOLT | `bolt/` | `Utils.cpp` translation unit |
| Polly | `polly/` | `PollyDebug.cpp` translation unit |
| Documentation | Markdown, reStructuredText | UTF-8/path integrity |
| Pipeline | `.buildkite/` | shell and pipeline validation |

These are representative build targets, not exhaustive release builds. That
keeps the demo useful on ephemeral agents while still performing real C/C++
configuration and compilation.

The pipeline requests two-commit shallow clones so discovery can compute the
first-parent diff. Hosted Agent checkout hooks may substitute their managed Git
mirror strategy: a cold run can populate the full LLVM mirror, while later runs
benefit from the warm mirror cache.

## Hosted Agent measurements

Buildkite Hosted Agents are billed per vCPU-minute, measured to the second. At
the current published Linux rate of **$0.004 per vCPU-minute**, the configured
Small Linux agents (2 vCPU) cost **$0.008 per running job-minute**. Full mode
naturally fans all 12 generated lanes out concurrently when capacity permits.

| Mode | Generated work | Elapsed | Peak concurrency | Agent-minutes | vCPU-minutes | Usage cost |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Verified fast talk track | bootstrap + detector + 3 builds | 2m 18s | 3 | 4.31 | 8.62 | $0.035 |
| Verified full fan-out | bootstrap + detector + 11 builds + docs | 4m 50s | 12 | 17.10 | 34.20 | $0.137 |

The full measurement is [Build #6](https://buildkite.com/buildkite-solutions/llvm-monorepo-demo/builds/6),
an all-green warm-mirror run of commit `89949c68ef7b`. It ran from
21:14:40.497Z to 21:19:30.418Z on July 18, 2026. An earlier cold-cache
diagnostic caused multiple agents to populate LLVM's roughly 3.5 GiB Git
mirror, demonstrating that checkout cache state can dominate a first run.
Actual billed vCPU-minutes are `sum(job runtime × job vCPU)`, so the Buildkite
Usage page remains authoritative after a run.

## Files

- `bootstrap.yml` is copied to the Buildkite pipeline settings so the New Build
  dialog can collect the mode before an agent starts.
- `pipeline.yml` is the repository pipeline uploaded after mode selection.
- `scripts/changed-files.sh` is the plugin's newline-delimited diff command.
- `scripts/build-component.sh` maps each lane to a small real CMake/Ninja build.

The Buildkite pipeline has no webhook and the demo branch has no pull request,
so this configuration does not propagate to upstream LLVM.

## References

- [Monorepo Diff Buildkite Plugin](https://github.com/buildkite-plugins/monorepo-diff-buildkite-plugin)
- [Buildkite Hosted Agents](https://buildkite.com/docs/agent/buildkite-hosted)
- [Hosted Agent pricing](https://buildkite.com/pricing/)
- [Dynamic pipelines](https://buildkite.com/docs/pipelines/configure/dynamic-pipelines)
