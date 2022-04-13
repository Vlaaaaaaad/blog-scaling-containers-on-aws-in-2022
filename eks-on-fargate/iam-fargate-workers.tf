
data "aws_iam_policy_document" "fargate_pod_execution" {
  # Allow Fargate worker nodes to download images from ECR and ECR Public
  # ECR is restricted to AWS images, see https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html
  # ECR Public does not support restrictions (but can be mirrored to ECR Private)
  statement {
    sid = "ecrtoken"

    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr-public:GetAuthorizationToken",
      "sts:GetServiceBearerToken",
    ]
    resources = [
      "*",
    ]
  }
  statement {
    sid = "ecrget"

    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = [
      # Fluentbit containers are pulled from ECR Public
      #  https://gallery.ecr.aws/aws-observability/aws-for-fluent-bit
      #  which does not support restrictions
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/test-app-2022",
    ]
    # Force pulling over VPC Endpoints
    condition {
      test     = "StringEquals"
      variable = "aws:sourceVpc"
      values = [
        module.vpc.vpc_id,
      ]
    }
    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:sourceVpce"
      values = [
        module.endpoints.endpoints["s3"].id,
        module.endpoints.endpoints["ecr_api"].id,
        module.endpoints.endpoints["ecr_dkr"].id,
      ]
    }
  }
  # CloudWatch Logging permissions
  statement {
    sid = "cloudwatchput"

    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams",
      "logs:CreateLogStream",
    ]
    resources = [
      "*",
    ]
  }
}

resource "aws_iam_policy" "fargate_pod_execution" {
  name        = "${local.cluster_name}-fargate-pod-execution"
  description = "A policy that gives Fargate the permissions required to setup and start pods"

  policy = data.aws_iam_policy_document.fargate_pod_execution.json
}

data "aws_iam_policy_document" "fargate_pod_execution_assume" {
  statement {
    sid     = "EKSNodeAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks-fargate-pods.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "fargate_pod_execution" {
  name        = "${local.cluster_name}-fargate-pods-execution-role"
  description = "The pod execution role for Fargate workers"

  assume_role_policy    = data.aws_iam_policy_document.fargate_pod_execution_assume.json
  force_detach_policies = true

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "attach_eks_fargate_workers_permissions" {
  role       = aws_iam_role.fargate_pod_execution.name
  policy_arn = aws_iam_policy.fargate_pod_execution.arn
}
