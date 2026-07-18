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

The same form can add a checkout-performance lab:

- **Off (default):** run only the selected build fan-out.
- **Quick:** compare a depth-1 GitHub clone with Buildkite's attached Git mirror.
- **Full history:** repeat the comparison with the repository's multi-gigabyte
  history. This is the strongest prospect demonstration, but intentionally
  downloads the complete repository once for the uncached baseline.

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

Normal build jobs use Buildkite's native two-commit shallow checkout so
discovery can compute the first-parent diff. The Hosted Agent also attaches its
managed Git mirror, so the shallow working checkout can borrow existing objects
instead of transferring them again.

## Checkout performance lab

The lab creates a prospect-friendly three-step group in the Buildkite
waterfall:

1. **Uncached network clone** fetches the selected history directly from
   GitHub with no job-local object cache.
2. **Buildkite Git mirror clone** checks out the identical commit using the
   cluster's attached mirror and Git's `--reference-if-able` object borrowing.
3. **Checkout comparison** downloads both result artifacts and publishes a
   Buildkite annotation with clone time, working-tree materialization time,
   local object storage, speedup, and projected savings across 12 lanes.

The stopwatch covers the controlled `git clone` plus `git checkout`. Queueing,
agent startup, and each benchmark job's identical native Buildkite checkout are
excluded, so the two samples are directly comparable. Raw Git output and JSON
metrics are kept as build artifacts for follow-up with a prospect.

### Verified checkout results

Both profiles produced the same **2.56 GiB working tree with 180,914 tracked
files** on July 18, 2026.

| Profile | History delivered | Network Git time | Mirror Git time | Speedup | Time saved | Job-local objects avoided |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| [Quick — Build #8](https://buildkite.com/buildkite-solutions/llvm-monorepo-demo/builds/8) | depth 1 / 291 MiB | 37.869s | 12.363s | 3.06× | 25.506s / 67.4% | 291 MiB |
| [Full history — Build #9](https://buildkite.com/buildkite-solutions/llvm-monorepo-demo/builds/9) | 3.76 GiB | 3m 24.349s | 6.924s | 29.51× | 3m 17.425s / 96.6% | 3.76 GiB |

In the full-history Buildkite waterfall, the complete uncached benchmark job
took **3m 36.366s** while the mirror job took **18.438s**. Repeating the
measured Git-time saving across the demo's 12 generated lanes represents about
**39.49 agent-minutes** and **$0.316** of Hosted Agent usage avoided per build.

The Hosted Agents cluster currently has Git mirror volumes enabled, including
a 5 GiB `buildkite-git-mirror-pbuckley-llvm-project` volume. These volumes are
cluster-scoped, backed by high-performance NVMe storage, and attached on a
best-effort basis. A miss falls back safely to GitHub; successful jobs refresh
the cache for later builds.

### Demo talk track

- Start with **Fast + Quick** for a short, repeatable meeting demo.
- Open the checkout annotation and emphasize that both jobs produced the same
  commit, working-tree size, and tracked-file count.
- Point out that the mirror checkout stores very few objects in the ephemeral
  job because it borrows from the shared cache volume.
- Re-run as **Fast + Full history** when the prospect wants the multi-GB cold
  clone comparison. The cached side remains a local reference checkout.
- Relate the per-checkout saving to the 12-way LLVM fan-out: network and disk
  savings multiply with every parallel monorepo lane.

### Optimizations demonstrated

| Optimization | Demo implementation | Why it matters |
| --- | --- | --- |
| Git mirror volume | Native Hosted Agent mirror, shared within the cluster | Avoids repeatedly transferring large Git object graphs |
| Shallow checkout | `checkout.depth: 2` for normal build jobs | Preserves first-parent diffing without fetching unnecessary history |
| No submodules | `checkout.submodules: false` | Avoids work LLVM does not need for these targets |
| Dynamic fan-out | `monorepo-diff#v1.11.0` | Avoids provisioning and checking out untouched project lanes |

For production extensions, Buildkite also supports native sparse checkout for
path-focused jobs, pipeline cache volumes for tool/build data, and durable
artifact or remote caches where best-effort local state is not appropriate.

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
- `checkout-lab.yml` defines the parallel uncached and mirror comparison.
- `scripts/changed-files.sh` is the plugin's newline-delimited diff command.
- `scripts/build-component.sh` maps each lane to a small real CMake/Ninja build.
- `scripts/checkout-benchmark.sh` records controlled clone/checkout metrics.
- `scripts/compare-checkouts.py` renders the annotation and savings model.

The Buildkite pipeline has no webhook and the demo branch has no pull request,
so this configuration does not propagate to upstream LLVM.

## References

- [Monorepo Diff Buildkite Plugin](https://github.com/buildkite-plugins/monorepo-diff-buildkite-plugin)
- [Buildkite Hosted Agents](https://buildkite.com/docs/agent/buildkite-hosted)
- [Hosted Agent cache volumes](https://buildkite.com/docs/agent/buildkite-hosted/cache-volumes)
- [Git checkout optimization](https://buildkite.com/docs/pipelines/best-practices/git-checkout-optimization)
- [Hosted Agent pricing](https://buildkite.com/pricing/)
- [Dynamic pipelines](https://buildkite.com/docs/pipelines/configure/dynamic-pipelines)
