locals {
  # AWS-managed ECR Repositories for Bottlerocket images
  # See https://github.com/bottlerocket-os/bottlerocket/blob/develop/sources/api/schnauzer/src/helpers.rs
  #  and https://github.com/bottlerocket-os/bottlerocket/issues/857
  bottlerocket_ecr_image_accounts_lookup = {
    "af-south-1"     = "917644944286"
    "ap-east-1"      = "375569722642"
    "ap-northeast-1" = "328549459982"
    "ap-northeast-2" = "328549459982"
    "ap-northeast-3" = "328549459982"
    "ap-south-1"     = "328549459982"
    "ap-southeast-1" = "328549459982"
    "ap-southeast-2" = "328549459982"
    "ca-central-1"   = "328549459982"
    "eu-central-1"   = "328549459982"
    "eu-north-1"     = "328549459982"
    "eu-south-1"     = "586180183710"
    "eu-west-1"      = "328549459982"
    "eu-west-2"      = "328549459982"
    "eu-west-3"      = "328549459982"
    "me-south-1"     = "509306038620"
    "sa-east-1"      = "328549459982"
    "us-east-1"      = "328549459982"
    "us-east-2"      = "328549459982"
    "us-west-1"      = "328549459982"
    "us-west-2"      = "328549459982"
  }
}


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
      # Base OS components
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${local.bottlerocket_ecr_image_accounts_lookup[data.aws_region.current.name]}:repository/bottlerocket-control",
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${local.bottlerocket_ecr_image_accounts_lookup[data.aws_region.current.name]}:repository/bottlerocket-admin",
      # Apps
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

  # Copied from  arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
  # Allow SSM connections to EC2 worker nodes
  statement {
    sid = "ssmmanagedinstancecore"

    effect = "Allow"
    actions = [
      "ssm:DescribeAssociation",
      "ssm:GetDeployablePatchSnapshotForInstance",
      "ssm:GetDocument",
      "ssm:DescribeDocument",
      "ssm:GetManifest",
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:ListAssociations",
      "ssm:ListInstanceAssociations",
      "ssm:PutInventory",
      "ssm:PutComplianceItems",
      "ssm:PutConfigurePackageResult",
      "ssm:UpdateAssociationStatus",
      "ssm:UpdateInstanceAssociationStatus",
      "ssm:UpdateInstanceInformation",
      "ssmmessages:CreateControlChannel",
      "ssmmessages:CreateDataChannel",
      "ssmmessages:OpenControlChannel",
      "ssmmessages:OpenDataChannel",
      "ec2messages:AcknowledgeMessage",
      "ec2messages:DeleteMessage",
      "ec2messages:FailMessage",
      "ec2messages:GetEndpoint",
      "ec2messages:GetMessages",
      "ec2messages:SendReply",
    ]
    resources = [
      "*",
    ]
  }

  # CloudWatch Container permissions
  statement {
    sid = "cloudwatchput"

    effect = "Allow"
    actions = [
      "ec2:DescribeTags",
      "ecs:CreateCluster",
      "ecs:DeregisterContainerInstance",
      "ecs:DiscoverPollEndpoint",
      "ecs:Poll",
      "ecs:RegisterContainerInstance",
      "ecs:StartTelemetrySession",
      "ecs:UpdateContainerInstancesState",
      "ecs:Submit*",
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
        "ec2.amazonaws.com",
        "ecs-tasks.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_policy" "workers" {
  name        = "ec2-workers-${local.cluster_name}"
  description = "A policy that gives IAM rights to ECS-on-EC2 tasks"

  policy = data.aws_iam_policy_document.policy_doc.json
}

resource "aws_iam_role_policy_attachment" "attach_permissions_workers" {
  role       = aws_iam_role.task_execution_role.id
  policy_arn = aws_iam_policy.workers.arn
}

resource "aws_iam_role_policy_attachment" "attach_ssm_permissions_workers" {
  role       = aws_iam_role.task_execution_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "ecs-on-ec2-workers-${local.cluster_name}"
  role = aws_iam_role.task_execution_role.name
}
