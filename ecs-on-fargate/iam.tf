resource "aws_iam_role" "task_role" {
  name               = "task-${local.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json

  # The app does not call any AWS APIs, so no permissions are attached
}

resource "aws_iam_role" "task_execution_role" {
  name               = "execution-${local.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.task_assume.json
}

data "aws_iam_policy_document" "policy_doc" {
  # AWS ECR Image Pulling permissions
  statement {
    sid = "ecrtoken"

    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
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
      test     = "StringEquals"
      variable = "aws:sourceVpce"
      values = [
        module.endpoints.endpoints["s3"].id,
        module.endpoints.endpoints["ecr_api"].id,
        module.endpoints.endpoints["ecr_dkr"].id,
      ]
    }
  }

  # CloudWatch Container permissions
  statement {
    sid = "cloudwatchput"

    effect = "Allow"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
    ]
    resources = [
      "*",
    ]
  }
}

data "aws_iam_policy_document" "task_assume" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"
      identifiers = [
        "ecs-tasks.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_policy" "workers" {
  name        = "fargate-workers-${local.cluster_name}"
  description = "A policy that gives IAM rights to ECS-on-Fargate tasks"

  policy = data.aws_iam_policy_document.policy_doc.json
}

resource "aws_iam_role_policy_attachment" "attach_permissions_ondemand_workers" {
  role       = aws_iam_role.task_execution_role.id
  policy_arn = aws_iam_policy.workers.arn
}
