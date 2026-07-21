variable "buildkite_organization_slug" {
  description = "Buildkite organization containing the demo pipelines."
  type        = string
  default     = "buildkite-solutions"
}

variable "buildkite_pipeline_repository" {
  description = "Shared LLVM monorepo used by every product pipeline."
  type        = string
  default     = "https://github.com/pbuckley/llvm-project.git"
}

variable "buildkite_pipeline_default_branch" {
  description = "Demo-only branch containing the product pipeline files."
  type        = string
  default     = "codex/buildkite-monorepo-demo"
}

variable "buildkite_hosted_cluster_graphql_id" {
  description = "GraphQL ID of the Buildkite Hosted Agents cluster."
  type        = string
  default     = "Q2x1c3Rlci0tLTUyNzc2ODk1LTkyYzItNGFiZi05YjQyLTJkNDEzYmE1YzkxNA=="
}

variable "buildkite_default_team_graphql_id" {
  description = "GraphQL ID of the team initially granted access to the pipelines."
  type        = string
  default     = "VGVhbS0tLWM2YWFmYTE5LWI4Y2ItNGIyZC1iMmY3LWRiZjUxMTI3ZDAyMA=="
}
