# LLVM monorepo Buildkite demo

This private demo shows two idiomatic ways to operate a large monorepo. One
repository pipeline discovers the changed paths, and
`monorepo-diff#v1.11.0` either triggers independent product pipelines or
dynamically uploads the affected build lanes into one build.

## Running the demo

Use **New Build** in the `LLVM Monorepo Demo` pipeline. The form offers:

- **Fast — changed projects only (default):** compares the selected commit to
  its first parent and creates only matching lanes.
- **Full — all project lanes:** emits one representative path for every lane,
  creating all 11 code-build lanes plus documentation integrity.
- **Independent product pipelines (default):** each affected folder triggers
  its own Buildkite pipeline, history, scoped changelog, and release lineage.
- **Build lanes in one pipeline:** keeps the original compact 12-way fan-out
  visualization for the speed and concurrency discussion.
- **Failure recovery:** optionally makes MLIR Terraform slice 4/5 fail once.
  Buildkite retries only that job while the other product material is retained.

For a repeatable talk-track scenario, set the build environment variable
`LLVM_DEMO_CHANGED_PATHS` to comma-separated paths. For example:

```text
llvm/lib/IR/Verifier.cpp,clang/lib/Sema/Sema.cpp,lld/Common/DriverDispatcher.cpp
```

This override affects project selection only; each generated lane still checks
out and builds the real LLVM source at the chosen commit.

## Independent product pipelines and material lineage

The prospect-shaped path uses `.buildkite/product-orchestrator.yml` to map the
same 11 code roots to 11 private Buildkite pipelines. Terraform in
`infra/product-pipelines` manages those pipelines. A trigger passes the exact
monorepo commit, branch, diff base, and parent build URL to the product build.

Every product pipeline then demonstrates the incremental migration path:

1. A product-scoped annotation shows the commits and files entering that
   product's release and uploads an immutable JSON release manifest.
2. `conveyor test PRODUCT` and `conveyor package PRODUCT` retain the existing
   shell-command contract while Buildkite supplies orchestration and UI.
3. Five Terraform plan slices consume the package artifact with
   `BUILDKITE_SKIP_CHECKOUT=true`; none of those ephemeral jobs clones LLVM.
4. Promotion consumes the same package and plans, verifies the commit, and
   publishes a deployment record answering "where is my stuff?"

The optional `mlir-once` scenario fails one plan slice with exit status 42 on
its first attempt. Its retry succeeds by observing `BUILDKITE_RETRY_COUNT`; the
other four slices and every upstream artifact remain untouched.

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

Terraform creates a separate `LLVM EKS Mirror Demo` pipeline in the
`Self-Hosted K8s Stack (Demo)` cluster. Its New Build form offers Quick and Full
history profiles. The lab creates a three-step group:

1. **EKS network clone** fetches the selected history directly from GitHub and
   deliberately does not reference the attached mirror.
2. **Self-hosted EKS mirror clone** checks out the identical commit with Git's
   `--reference-if-able` object borrowing from the encrypted EFS mirror.
3. **Checkout comparison** downloads both result artifacts and publishes clone
   time, working-tree materialization time, local object storage, and speedup.

Both jobs run on the same `llvm-eks-mirror` queue, EKS worker group, and job
image. Mirror use is the controlled variable. Queueing, agent startup, native
Buildkite checkout, and artifact transfer are excluded from the stopwatch.
Raw Git output and JSON metrics remain available as build artifacts.

### Demo talk track

- Apply `infra/eks-mirror` before the meeting and run the Quick lab once to
  warm the EKS mirror. Keep the stack running for the live comparison.
- Start the `LLVM EKS Mirror Demo` pipeline with **Quick** for a short,
  repeatable meeting demo.
- Open the annotation and emphasize that both jobs used the same self-hosted
  compute and produced the same commit, working-tree size, and file count.
- Contrast direct network delivery with the customer-managed EKS/EFS mirror:
  job pods remain ephemeral while Git objects persist across jobs.
- Re-run with **Full history** when the prospect wants the multi-GB comparison.
- Relate the per-checkout saving to the 12-way LLVM fan-out: network and disk
  savings multiply with every parallel monorepo lane.

### Verified self-hosted EKS measurements

Both measurements used the same `llvm-eks-mirror` queue, EKS worker group,
container image, commit, and 180,935-file working tree. Mirror use was the only
controlled difference.

| Profile | Direct network Git time | EFS mirror Git time | Speedup | Job-local objects avoided |
| --- | ---: | ---: | ---: | ---: |
| Quick, depth 1 | 55.808s | 25.321s | 2.2x | about 292 MiB |
| Full, 4.08 GB mirror | 556.428s | 25.178s | 22.1x | about 3.80 GiB |

The full-history clone/fetch phase alone fell from **538.451s to 0.218s**; the
remaining 24.960s was working-tree materialization. See
[EKS Build #4](https://buildkite.com/buildkite-solutions/llvm-eks-mirror-demo/builds/4)
and [EKS Build #5](https://buildkite.com/buildkite-solutions/llvm-eks-mirror-demo/builds/5).

### Optimizations demonstrated

| Optimization | Demo implementation | Why it matters |
| --- | --- | --- |
| Self-hosted Git mirror | Agent Stack on EKS with an encrypted, ReadWriteMany EFS PVC | Shows the customer-controlled persistent mirror design |
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
- `product-orchestrator.yml` routes folders to independent product pipelines.
- `product-pipeline.yml` carries one product through lineage, test, package,
  isolated Terraform slices, and promotion. Each product checks out source once;
  the five plan slices and promotion consume immutable artifacts without another
  repository checkout.
- `eks-mirror-bootstrap.yml` is the Terraform-managed pipeline definition for
  choosing a checkout profile.
- `checkout-lab.yml` defines the two-way EKS network and EFS mirror comparison.
- `scripts/changed-files.sh` is the plugin's newline-delimited diff command.
- `scripts/build-component.sh` maps each lane to a small real CMake/Ninja build.
- `scripts/product-lineage.py` renders the per-product changelog and manifest.
- `scripts/conveyor-adapter.sh` preserves the customer's script-runner contract.
- `scripts/checkout-benchmark.sh` records controlled clone/checkout metrics.
- `scripts/compare-checkouts.py` renders the annotation and savings model.
- `../infra/eks-mirror/` provisions the dedicated Buildkite pipeline and queue,
  EKS, EFS, External Secrets, and Agent Stack resources.
- `../infra/product-pipelines/` provisions the 11 private product pipelines.

The main demo pipeline has a GitHub App webhook and commit statuses enabled.
The EKS and product pipelines use `trigger_mode: none` and are started only by
the demo workflow. The branch has no pull request and does not propagate to
upstream LLVM.

## References

- [Monorepo Diff Buildkite Plugin](https://github.com/buildkite-plugins/monorepo-diff-buildkite-plugin)
- [Buildkite Hosted Agents](https://buildkite.com/docs/agent/buildkite-hosted)
- [Hosted Agent cache volumes](https://buildkite.com/docs/agent/buildkite-hosted/cache-volumes)
- [Git checkout optimization](https://buildkite.com/docs/pipelines/best-practices/git-checkout-optimization)
- [Agent Stack for Kubernetes Git mirrors](https://buildkite.com/docs/agent/self-hosted/agent-stack-k8s/git-settings)
- [Terraform self-hosted queue management](https://buildkite.com/docs/platform/terraform-provider/manage-clusters-and-queues)
- [Hosted Agent pricing](https://buildkite.com/pricing/)
- [Dynamic pipelines](https://buildkite.com/docs/pipelines/configure/dynamic-pipelines)
