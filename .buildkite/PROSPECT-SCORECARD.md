# Prospect-fit scorecard and morning plan

This is the critical handoff view after the self-hosted EKS mirror and
independent product-pipeline work. Scores measure how well the demo proves the
prospect's stated concern, not whether Buildkite supports the capability.

## Current evidence

| Prospect expectation | Evidence ready to show | Confidence | Remaining gap |
| --- | --- | ---: | --- |
| Large monorepo checkout performance | Same-queue EKS comparison: 556.428s direct versus 25.178s through the EFS mirror | Strong | Their repository and storage behavior still require a POC |
| Ephemeral EKS agents with persistent cache | Terraform provisions Agent Stack for Kubernetes, EFS, encrypted RWX PVC, and the mirror queue | Strong | Demo is not their cluster, IAM, or network policy |
| Per-folder product ownership | The diff router triggers 11 independently deployed private pipelines with separate histories | Strong | Pattern is 11 products rather than their roughly 40 |
| Product changelog and “where is my stuff?” | Each child publishes scoped commits/files, immutable manifest, checksum, plans, and promotion record | Strong | Promotion is a traceability demonstration, not a real environment |
| Keep Conveyor during migration | Adapter preserves the command boundary while Buildkite owns routing and visibility | Moderate | Customer Conveyor is unavailable; the demo substitutes a real LLVM target |
| Late failure must not rebuild everything | MLIR Build #2 automatically retries only plan slice 4/5; upstream package and other slices remain intact | Strong | Failure is controlled rather than a real Terraform failure |
| Under-one-hour build-to-deploy | 12-lane build completed in 4m50s; routed product flow completed in 2m39s | Directional | These are representative targets, not their release workload |
| Security and network posture | Self-hosted agents use an outbound control connection and customer-owned source/cache execution | Moderate | Enterprise auth, secrets, audit, and allowlist review need customer specifics |
| POC and migration support | Runbook defines an incremental GoCD/script-runner migration story | Partial | Owners, success criteria, timeline, and escalation model must be agreed live |

Overall: the demo is strong on the two hardest technical objections—source
delivery and failure isolation—and credible on product ownership and lineage.
It should be presented as a production-shaped POC pattern, not a benchmark of
the customer's final build or a completed Conveyor/Terraform migration.

## Under-three-hour morning plan

1. **0:00–0:25 — preflight the evidence.** Confirm the EKS queue is online;
   open EKS Builds #4/#5, product Build #13, and full fan-out Build #6; verify
   the latest branch commit still routes Clang, MLIR, and LLDB.
2. **0:25–1:05 — rehearse the six-minute narrative.** Start at their 15-minute
   pull problem, show the controlled mirror result, route three products, open
   one lineage annotation, then expose MLIR's single automatic retry.
3. **1:05–1:35 — prepare the POC close.** Write down their owners and propose
   measurable gates: checkout p50/p95, build-to-deploy critical path, cache hit
   ratio, concurrency ceiling, and one Conveyor-backed product migrated intact.
4. **1:35–2:05 — prepare security answers.** Confirm what stays in customer
   infrastructure versus the SaaS control plane, then list the details that
   require their review: egress, secrets source, log content, IAM, and retention.
5. **2:05–2:30 — run one clean Fast build only if needed.** Use Fast + product
   pipelines + failure recovery off. Do not replace the known-good evidence if
   the live queue is cold or noisy.
6. **2:30–2:50 — stage fallbacks.** Keep direct links and this runbook in one
   browser window; retain 10 minutes to recover from login or queue issues.

Defer cosmetic UI work, scaling from 11 to 40 copied pipelines, and any attempt
to mimic the customer's entire Terraform deployment. Those consume morning
time without closing a stronger evaluation gap.
