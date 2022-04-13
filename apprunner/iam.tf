data "aws_iam_policy_document" "instance_assume" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"
      identifiers = [
        "tasks.apprunner.${data.aws_partition.current.dns_suffix}",
      ]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${local.cluster_name}-instance"
  assume_role_policy = data.aws_iam_policy_document.instance_assume.json

  # The app does not call any AWS APIs, so no permissions are attached
}




resource "aws_iam_role" "access" {
  name               = "access-${local.cluster_name}"
  assume_role_policy = data.aws_iam_policy_document.access_assume.json
}

data "aws_iam_policy_document" "access_assume" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"
      identifiers = [
        "build.apprunner.${data.aws_partition.current.dns_suffix}",
      ]
    }
  }
}

data "aws_iam_policy_document" "access_perms" {
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
      "ecr:DescribeImages",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/test-app-2022",
    ]
  }
}

resource "aws_iam_policy" "access" {
  name        = "${local.cluster_name}-access"
  description = "A policy that gives IAM Access rights to AppRunner tasks"

  policy = data.aws_iam_policy_document.access_perms.json
}

resource "aws_iam_role_policy_attachment" "attach_permissions_workers" {
  role       = aws_iam_role.access.id
  policy_arn = aws_iam_policy.access.arn
}
