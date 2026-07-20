variable "aws_region" {
  description = "AWS Region in which to create the EKS mirror stack."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix used for AWS and Kubernetes resources."
  type        = string
  default     = "llvm-eks-mirror"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,31}$", var.project_name))
    error_message = "project_name must be 3-32 lowercase letters, digits, or hyphens, starting with a letter."
  }
}

variable "vpc_cidr" {
  description = "CIDR for the dedicated demo VPC."
  type        = string
  default     = "10.42.0.0/16"
}

variable "kubernetes_version" {
  description = "EKS Kubernetes version. Agent Stack 0.46.0 validates against Kubernetes 1.35 schemas."
  type        = string
  default     = "1.35"
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Operator CIDRs allowed to reach the public EKS API endpoint. Use explicit /32 addresses for the demo."
  type        = list(string)
  default     = ["73.100.130.210/32"]

  validation {
    condition = (
      length(var.cluster_endpoint_public_access_cidrs) > 0 &&
      !contains(var.cluster_endpoint_public_access_cidrs, "0.0.0.0/0") &&
      !contains(var.cluster_endpoint_public_access_cidrs, "::/0")
    )
    error_message = "Provide at least one restricted operator CIDR; public internet CIDRs are not allowed."
  }
}

variable "node_instance_types" {
  description = "On-demand instance types for the mirror worker group."
  type        = list(string)
  default     = ["m7i.large"]
}

variable "node_min_size" {
  description = "Minimum number of EKS worker nodes."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of EKS worker nodes."
  type        = number
  default     = 4
}

variable "node_desired_size" {
  description = "Initial number of EKS worker nodes."
  type        = number
  default     = 2
}

variable "buildkite_organization_slug" {
  description = "Buildkite organization containing the LLVM demo pipeline."
  type        = string
  default     = "buildkite-solutions"
}

variable "buildkite_cluster_graphql_id" {
  description = "GraphQL ID of the Self-Hosted K8s Stack (Demo) Buildkite cluster."
  type        = string
  default     = "Q2x1c3Rlci0tLTQ2YmMwN2VlLTViOWYtNGE2Zi1iZGI1LWI5NzNjZDU3ZDUwNQ=="
}

variable "buildkite_queue_key" {
  description = "Self-hosted queue key targeted by the EKS mirror demo step."
  type        = string
  default     = "llvm-eks-mirror"
}

variable "buildkite_pipeline_name" {
  description = "Name of the dedicated two-way checkout demo pipeline."
  type        = string
  default     = "LLVM EKS Mirror Demo"
}

variable "buildkite_pipeline_repository" {
  description = "LLVM repository cloned by the checkout demo."
  type        = string
  default     = "https://github.com/pbuckley/llvm-project.git"
}

variable "buildkite_pipeline_default_branch" {
  description = "Default branch containing the demo pipeline files."
  type        = string
  default     = "codex/buildkite-monorepo-demo"
}

variable "buildkite_default_team_graphql_id" {
  description = "GraphQL ID of the Buildkite team initially granted access to the demo pipeline."
  type        = string
  default     = "VGVhbS0tLWM2YWFmYTE5LWI4Y2ItNGIyZC1iMmY3LWRiZjUxMTI3ZDAyMA=="
}

variable "buildkite_agent_token_secret_arn" {
  description = <<-EOT
    ARN of an existing Secrets Manager secret in aws_region. The secret must
    contain JSON with a BUILDKITE_AGENT_TOKEN key for the Self-Hosted K8s Stack
    (Demo) cluster. The secret value is never read by Terraform.
  EOT
  type        = string
  default     = "arn:aws:secretsmanager:us-east-1:097340723131:secret:buildkite-solutions/llvm-demo-agent-token-BLUmfz"

  validation {
    condition     = can(regex("^arn:[^:]+:secretsmanager:[^:]+:[0-9]{12}:secret:", var.buildkite_agent_token_secret_arn))
    error_message = "buildkite_agent_token_secret_arn must be a Secrets Manager secret ARN."
  }
}

variable "buildkite_agent_token_kms_key_arn" {
  description = "Optional customer-managed KMS key ARN used by the token secret. Leave null when the secret uses the AWS managed key."
  type        = string
  default     = null

  validation {
    condition     = var.buildkite_agent_token_kms_key_arn == null || can(regex("^arn:[^:]+:kms:[^:]+:[0-9]{12}:key/", var.buildkite_agent_token_kms_key_arn))
    error_message = "buildkite_agent_token_kms_key_arn must be a KMS key ARN or null."
  }
}

variable "buildkite_agent_stack_version" {
  description = "Buildkite Agent Stack for Kubernetes Helm chart version."
  type        = string
  default     = "0.46.0"
}

variable "buildkite_job_image" {
  description = "Ubuntu-based Buildkite agent image used by checkout and command containers."
  type        = string
  default     = "ghcr.io/buildkite/agent:3.123.1-ubuntu-24.04"
}

variable "external_secrets_chart_version" {
  description = "External Secrets Operator Helm chart version."
  type        = string
  default     = "2.8.0"
}

variable "mirror_pvc_size" {
  description = "Requested PVC size. EFS is elastic; this is the Kubernetes request shown in the demo."
  type        = string
  default     = "20Gi"
}

variable "tags" {
  description = "Additional tags applied to AWS resources."
  type        = map(string)
  default     = {}
}
