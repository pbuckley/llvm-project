# Prospect demo runbook

## Preflight

- Keep `codex/buildkite-monorepo-demo` selected in all New Build forms.
- Confirm the `LLVM EKS Mirror Demo` queue is active before the meeting.
- Keep these known-good results open as fallbacks:
  - [Product routing, lineage, artifact fan-out, and isolated retry](https://buildkite.com/buildkite-solutions/llvm-monorepo-demo/builds/13)
  - [12-way LLVM fan-out, 4m50s](https://buildkite.com/buildkite-solutions/llvm-monorepo-demo/builds/6)
  - [EKS full-history mirror comparison](https://buildkite.com/buildkite-solutions/llvm-eks-mirror-demo/builds/4)
  - [EKS quick mirror comparison](https://buildkite.com/buildkite-solutions/llvm-eks-mirror-demo/builds/5)
- Verify the latest commit touches the demo marker files in Clang, MLIR, and
  LLDB. That makes Fast mode produce three predictable product pipelines.

## Recommended live sequence

1. Start with EKS Build #4's annotation. Explain that both ephemeral pods ran
   in the customer's topology; the encrypted EFS mirror is the controlled
   variable. Use total Git time (**556.428s versus 25.178s, 22.1x**) rather than
   claiming the 0.218s reference clone is the entire checkout.
2. Run `LLVM Monorepo Demo` with **Fast**, **Independent product pipelines**,
   and **Failure recovery off**. The router should trigger Clang, MLIR, and LLDB.
3. Open one child pipeline's annotation. Point to the scoped commit, changed
   file, immutable manifest, parent orchestrator link, and product history.
4. Follow the material through `conveyor test`, package, five Terraform slices,
   and promotion. Emphasize that the Terraform and promotion jobs explicitly
   skip Git checkout and consume artifacts. Be explicit that the checked-in
   adapter preserves the customer's command boundary but uses a real LLVM
   target as the demo substitute because their Conveyor binary is unavailable.
5. Run the same Fast scenario with **MLIR fails once**. In MLIR, expose retried
   jobs and show only Terraform slice 4/5 retrying; no upstream rebuild occurs.
6. Use Build #6 for the optional scale reveal: 12 naturally parallel LLVM lanes
   completed in 4m50s. Do not present it as proof that the customer's entire
   build-to-deploy path will finish within one hour.

## Security and migration talk track

- Self-hosted agents make outbound TLS connections; Buildkite does not need an
  inbound route to the customer's EKS cluster.
- Source, credentials, the EFS Git mirror, and package execution stay in the
  customer environment. The SaaS control plane coordinates jobs and receives
  the logs and results the customer chooses to emit.
- Phase 1 keeps `conveyor test`, packaging, and Terraform commands intact while
  replacing GoCD orchestration and visibility. Later phases can optimize or
  replace Conveyor without blocking the migration.

## Claims to avoid

- The 4m50s LLVM run proves dynamic scheduling and concurrency, not the
  customer's under-one-hour build-to-deploy target.
- The EKS result proves this mirror/PVC design, not that every storage class or
  existing customer mirror will produce the same speedup.
- Eleven product pipelines are a faithful pattern for their roughly 40
  products, not a claim that the demo has the same source size or workload mix.
- The Terraform plan files and promotion record demonstrate orchestration and
  lineage; they do not deploy customer infrastructure.
