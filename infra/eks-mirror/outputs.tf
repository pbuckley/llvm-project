output "eks_cluster_name" {
  description = "EKS cluster created for the self-hosted mirror queue."
  value       = module.eks.cluster_name
}

output "buildkite_queue_key" {
  description = "Queue targeted by the EKS checkout benchmark step."
  value       = buildkite_cluster_queue.eks_mirror.key
}

output "buildkite_queue_uuid" {
  description = "Buildkite UUID of the self-hosted queue."
  value       = buildkite_cluster_queue.eks_mirror.uuid
}

output "buildkite_pipeline_slug" {
  description = "Slug of the dedicated EKS mirror demo pipeline."
  value       = buildkite_pipeline.eks_mirror_demo.slug
}

output "buildkite_pipeline_url" {
  description = "URL of the dedicated EKS mirror demo pipeline."
  value       = "https://buildkite.com/${var.buildkite_organization_slug}/${buildkite_pipeline.eks_mirror_demo.slug}"
}

output "efs_file_system_id" {
  description = "Encrypted EFS file system backing the shared Git mirror."
  value       = aws_efs_file_system.git_mirrors.id
}

output "mirror_pvc_name" {
  description = "ReadWriteMany PVC mounted by Agent Stack checkout and command containers."
  value       = local.mirror_persistent_volume_claim
}

output "configure_kubectl_command" {
  description = "Command to add the demo EKS cluster to the local kubeconfig."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "verification_commands" {
  description = "Read-only checks to run after apply."
  value = [
    "kubectl -n ${local.buildkite_namespace} get deploy,pvc,externalsecret",
    "kubectl -n ${local.buildkite_namespace} rollout status deployment/agent-stack-k8s --timeout=5m",
  ]
}
