resource "buildkite_cluster_queue" "eks_mirror" {
  cluster_id = var.buildkite_cluster_graphql_id
  key        = var.buildkite_queue_key
  description = (
    "Self-hosted EKS queue with a persistent LLVM Git mirror for the product demo"
  )

  dispatch_paused      = false
  retry_agent_affinity = "prefer-warmest"
}

resource "buildkite_pipeline" "eks_mirror_demo" {
  name            = var.buildkite_pipeline_name
  description     = "Two-way LLVM checkout demo - network versus self-hosted EKS and EFS Git mirror"
  repository      = var.buildkite_pipeline_repository
  default_branch  = var.buildkite_pipeline_default_branch
  cluster_id      = var.buildkite_cluster_graphql_id
  default_team_id = var.buildkite_default_team_graphql_id
  steps           = file("${path.module}/../../.buildkite/eks-mirror-bootstrap.yml")

  provider_settings = {
    trigger_mode = "none"
  }

  depends_on = [buildkite_cluster_queue.eks_mirror]
}
