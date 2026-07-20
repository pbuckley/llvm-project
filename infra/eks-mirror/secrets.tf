resource "aws_iam_role" "external_secrets" {
  name               = "${local.name}-external-secrets"
  assume_role_policy = data.aws_iam_policy_document.eks_pod_identity_trust.json
}

data "aws_iam_policy_document" "external_secrets" {
  statement {
    sid    = "ReadBuildkiteAgentToken"
    effect = "Allow"
    actions = [
      "secretsmanager:DescribeSecret",
      "secretsmanager:GetSecretValue",
    ]
    resources = [var.buildkite_agent_token_secret_arn]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["true"]
    }
  }

  dynamic "statement" {
    for_each = var.buildkite_agent_token_kms_key_arn == null ? [] : [var.buildkite_agent_token_kms_key_arn]

    content {
      sid       = "DecryptBuildkiteAgentToken"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:DescribeKey"]
      resources = [statement.value]

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["secretsmanager.${var.aws_region}.amazonaws.com"]
      }

      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["true"]
      }
    }
  }
}

resource "aws_iam_role_policy" "external_secrets" {
  name   = "read-buildkite-agent-token"
  role   = aws_iam_role.external_secrets.id
  policy = data.aws_iam_policy_document.external_secrets.json
}

resource "aws_eks_pod_identity_association" "external_secrets" {
  cluster_name    = module.eks.cluster_name
  namespace       = local.external_secrets_namespace
  service_account = local.external_secrets_account
  role_arn        = aws_iam_role.external_secrets.arn

  depends_on = [aws_iam_role_policy.external_secrets]
}
