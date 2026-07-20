data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_partition" "current" {}

locals {
  name = substr(var.project_name, 0, 32)
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  buildkite_namespace            = "buildkite"
  external_secrets_namespace     = "external-secrets"
  external_secrets_account       = "external-secrets"
  agent_token_k8s_secret_name    = "buildkite-agent-token"
  mirror_storage_class_name      = "buildkite-efs"
  mirror_persistent_volume_claim = "buildkite-git-mirrors"

  tags = merge(
    {
      Environment = "demo"
      ManagedBy   = "Terraform"
      Project     = var.project_name
      Repository  = "pbuckley/llvm-project"
    },
    var.tags,
  )
}
