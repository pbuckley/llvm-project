data "aws_iam_policy_document" "eks_pod_identity_trust" {
  statement {
    sid     = "EksPodIdentity"
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "efs_csi" {
  name               = "${local.name}-efs-csi"
  assume_role_policy = data.aws_iam_policy_document.eks_pod_identity_trust.json
}

resource "aws_iam_role_policy_attachment" "efs_csi" {
  role = aws_iam_role.efs_csi.name
  policy_arn = format(
    "arn:%s:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy",
    data.aws_partition.current.partition,
  )
}

data "aws_eks_addon_version" "efs_csi" {
  addon_name         = "aws-efs-csi-driver"
  kubernetes_version = var.kubernetes_version
  most_recent        = true
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = local.name
  cidr = var.vpc_cidr

  azs = local.azs
  private_subnets = [
    for index, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, index)
  ]
  public_subnets = [
    for index, _ in local.azs : cidrsubnet(var.vpc_cidr, 8, index + 100)
  ]

  enable_dns_hostnames = true
  enable_dns_support   = true

  enable_nat_gateway = true
  single_nat_gateway = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.24.0"

  name               = local.name
  kubernetes_version = var.kubernetes_version

  endpoint_private_access      = true
  endpoint_public_access       = true
  endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  enable_cluster_creator_admin_permissions = true
  enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  addons = {
    coredns = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      before_compute = true
      most_recent    = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      before_compute = true
      most_recent    = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    mirror = {
      ami_type       = "AL2023_x86_64_STANDARD"
      capacity_type  = "ON_DEMAND"
      instance_types = var.node_instance_types

      min_size     = var.node_min_size
      max_size     = var.node_max_size
      desired_size = var.node_desired_size
      disk_size    = 100

      labels = {
        "buildkite.com/workload" = "mirror"
      }

      update_config = {
        max_unavailable_percentage = 50
      }
    }
  }
}

resource "aws_eks_pod_identity_association" "efs_csi" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "efs-csi-controller-sa"
  role_arn        = aws_iam_role.efs_csi.arn

  depends_on = [aws_iam_role_policy_attachment.efs_csi]
}

resource "aws_eks_addon" "efs_csi" {
  cluster_name  = module.eks.cluster_name
  addon_name    = data.aws_eks_addon_version.efs_csi.addon_name
  addon_version = data.aws_eks_addon_version.efs_csi.version

  preserve                    = true
  resolve_conflicts_on_create = "NONE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [aws_eks_pod_identity_association.efs_csi]
}
