resource "kubernetes_namespace" "amazon_cloudwatch" {
  metadata {
    annotations = {
      name = "amazon-cloudwatch"
    }

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }

    name = "amazon-cloudwatch"
  }
}

module "cw_agent_pod_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.8.0"

  create_role      = true
  role_name        = "${local.cluster_name}-irsa-cw-agent"
  role_description = "IRSA role for CloudWatch Agents and FluentBit"

  provider_url     = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns = [aws_iam_policy.cloudwatch_agent.arn]
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent",
    "system:serviceaccount:amazon-cloudwatch:fluent-bit",
  ]
  oidc_fully_qualified_audiences = ["sts.${data.aws_partition.current.dns_suffix}"]

  tags = local.tags
}

resource "aws_iam_policy" "cloudwatch_agent" {
  name   = "${local.cluster_name}-irsa-cw-agent"
  policy = data.aws_iam_policy_document.cloudwatch_agent.json

  tags = local.tags
}

data "aws_iam_policy_document" "cloudwatch_agent" {
  # CloudWatch Container Insights permissions
  # copied from arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
  statement {
    sid = "cloudwatchput"

    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
      "ec2:DescribeVolumes",
      "ec2:DescribeTags",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
    ]
    resources = [
      "*",
    ]
  }
  statement {
    sid = "cloudwatchgetparam"

    effect = "Allow"
    actions = [
      "ssm:GetParameter",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ssm:*:*:parameter/AmazonCloudWatch-*",
    ]
  }
}
