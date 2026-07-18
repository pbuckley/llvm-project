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
| C++ runtimes | `libcxx/`, `libcxxabi/`, `libunwind/`, `runtimes/` | `cxx` |
| MLIR | `mlir/` | `mlir-tblgen` |
| Flang | `flang/` | `FortranParser` |
| LLDB | `lldb/` | `lldb-argdumper` |
| compiler-rt | `compiler-rt/` | `builtins` |
| OpenMP/offload | `openmp/`, `offload/` | `omp` |
| BOLT | `bolt/` | `llvm-bolt-heatmap` |
| Polly | `polly/` | `Polly` |
| Documentation | Markdown, reStructuredText | UTF-8/path integrity |
| Pipeline | `.buildkite/` | shell and pipeline validation |

These are representative build targets, not exhaustive release builds. That
keeps the demo useful on ephemeral agents while still performing real C/C++
configuration and compilation.

Jobs use two-commit shallow clones so discovery can compute the first-parent
diff while generated build lanes avoid downloading LLVM's full history. This
bounds cold-cache transfer while remaining compatible with Hosted Agent Git
mirrors when a mirror volume is available.

## Hosted Agent estimate

The pipeline caps generated lanes at **4 concurrent jobs**. Buildkite Hosted
Agents are billed per vCPU-minute, measured to the second. At the current
published Linux rate of **$0.004 per vCPU-minute**, the configured Small Linux
agents (2 vCPU) cost **$0.008 per running job-minute**.

| Mode | Generated work | Peak concurrency | Agent-minutes | vCPU-minutes | Usage cost |
| --- | ---: | ---: | ---: | ---: | ---: |
| Verified fast talk track | bootstrap + detector + 3 builds | 3 | 4.31 | 8.62 | $0.035 |
| Fast planning range | bootstrap + detector + 3 builds | 3 | 4–15 | 8–30 | $0.03–$0.12 |
| Full fan-out estimate | bootstrap + detector + 11 builds + docs | 4 | 124–312 | 248–624 | $0.99–$2.50 |

The verified fast run completed in 2 minutes 18 seconds. The full estimate is
roughly 35–90 elapsed minutes at the four-job cap; its heavier project targets
make agent-minutes a better planning measure than multiplying the fast result.
Ranges include checkout and configuration. Git mirror/cache hits can reduce
them materially, while 30-minute lane timeouts bound individual code builds.
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
