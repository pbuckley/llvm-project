resource "aws_efs_file_system" "git_mirrors" {
  encrypted        = true
  performance_mode = "generalPurpose"
  throughput_mode  = "elastic"

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = {
    Name = "${local.name}-git-mirrors"
  }
}

resource "aws_security_group" "efs" {
  name        = "${local.name}-efs"
  description = "NFS access to the Buildkite Git mirror from EKS workers"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${local.name}-efs"
  }
}

resource "aws_vpc_security_group_ingress_rule" "efs_from_eks_nodes" {
  security_group_id            = aws_security_group.efs.id
  referenced_security_group_id = module.eks.node_security_group_id
  description                  = "NFS from EKS managed nodes"
  ip_protocol                  = "tcp"
  from_port                    = 2049
  to_port                      = 2049
}

resource "aws_efs_mount_target" "git_mirrors" {
  for_each = {
    for index, subnet_id in module.vpc.private_subnets : index => subnet_id
  }

  file_system_id  = aws_efs_file_system.git_mirrors.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]

  depends_on = [aws_vpc_security_group_ingress_rule.efs_from_eks_nodes]
}
