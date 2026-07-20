resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = var.external_secrets_chart_version
  namespace        = local.external_secrets_namespace
  create_namespace = true

  atomic  = true
  wait    = true
  timeout = 600

  values = [
    yamlencode({
      installCRDs = true
      serviceAccount = {
        create = true
        name   = local.external_secrets_account
      }
      resources = {
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }
      }
    }),
  ]

  depends_on = [
    module.eks,
    aws_eks_pod_identity_association.external_secrets,
  ]
}

resource "helm_release" "mirror_prerequisites" {
  name             = "mirror-prerequisites"
  chart            = "${path.module}/charts/mirror-prerequisites"
  namespace        = local.buildkite_namespace
  create_namespace = true

  atomic  = true
  wait    = true
  timeout = 600

  values = [
    yamlencode({
      awsRegion       = var.aws_region
      efsFileSystemId = aws_efs_file_system.git_mirrors.id
      mirror = {
        storageClassName          = local.mirror_storage_class_name
        persistentVolumeClaimName = local.mirror_persistent_volume_claim
        requestedStorage          = var.mirror_pvc_size
      }
      agentToken = {
        secretStoreName      = "aws-secrets-manager"
        awsSecretArn         = var.buildkite_agent_token_secret_arn
        awsSecretJsonKey     = "BUILDKITE_AGENT_TOKEN"
        kubernetesSecretName = local.agent_token_k8s_secret_name
        refreshInterval      = "1h"
      }
    }),
  ]

  depends_on = [
    helm_release.external_secrets,
    aws_efs_mount_target.git_mirrors,
  ]
}

resource "helm_release" "buildkite_agent_stack" {
  name             = "agent-stack-k8s"
  repository       = "oci://ghcr.io/buildkite/helm"
  chart            = "agent-stack-k8s"
  version          = var.buildkite_agent_stack_version
  namespace        = local.buildkite_namespace
  create_namespace = true

  atomic  = true
  wait    = true
  timeout = 900

  values = [
    yamlencode({
      agentStackSecret = local.agent_token_k8s_secret_name
      config = {
        image           = var.buildkite_job_image
        tags            = ["queue=${buildkite_cluster_queue.eks_mirror.key}"]
        "job-prefix"    = "llvm-mirror-"
        "max-in-flight" = 4
        "default-checkout-params" = {
          noSubmodules = true
          gitMirrors = {
            path        = "/buildkite/git-mirrors"
            lockTimeout = 1800
            skipUpdate  = false
            volume = {
              name = "git-mirrors"
              persistentVolumeClaim = {
                claimName = local.mirror_persistent_volume_claim
              }
            }
          }
        }
        "default-command-params" = {
          extraVolumeMounts = [{
            name      = "git-mirrors"
            mountPath = "/buildkite/git-mirrors"
          }]
        }
        "resource-classes" = {
          mirror = {
            nodeSelector = {
              "buildkite.com/workload" = "mirror"
            }
          }
        }
        "default-resource-class-name" = "mirror"
      }
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          memory = "512Mi"
        }
      }
    }),
  ]

  depends_on = [
    helm_release.mirror_prerequisites,
  ]
}
