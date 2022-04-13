locals {
  # AWS-managed ECR Repositories for official images
  # See https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html
  #  and https://github.com/aws/containers-roadmap/issues/1615
  eks_ecr_image_accounts_lookup = {
    "af-south-1"     = "877085696533"
    "ap-east-1"      = "800184023465"
    "ap-northeast-1" = "602401143452"
    "ap-northeast-2" = "602401143452"
    "ap-northeast-3" = "602401143452"
    "ap-south-1"     = "602401143452"
    "ap-southeast-1" = "602401143452"
    "ap-southeast-2" = "602401143452"
    "ca-central-1"   = "602401143452"
    "cn-north-1"     = "918309763551"
    "cn-northwest-1" = "961992271922"
    "eu-central-1"   = "602401143452"
    "eu-north-1"     = "602401143452"
    "eu-south-1"     = "590381155156"
    "eu-west-1"      = "602401143452"
    "eu-west-2"      = "602401143452"
    "eu-west-3"      = "602401143452"
    "me-south-1"     = "558608220178"
    "sa-east-1"      = "602401143452"
    "us-east-1"      = "602401143452"
    "us-east-2"      = "602401143452"
    "us-gov-east-1"  = "151742754352"
    "us-gov-west-1"  = "013241004608"
    "us-west-1"      = "602401143452"
    "us-west-2"      = "602401143452"
  }
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

data "aws_iam_policy_document" "eks_ec2_workers" {
  # Copied from arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
  # Allow worker nodes to connect to EKS
  statement {
    sid = "eksworkernodepolicy"

    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumesModifications",
      "ec2:DescribeVpcs",
      "eks:DescribeCluster",
    ]
    resources = [
      "*",
    ]
  }

  # Allow EC2 worker nodes to download images from ECR and ECR Public
  # ECR is restricted to AWS images,
  #  see https://docs.aws.amazon.com/eks/latest/userguide/add-ons-images.html
  # ECR Public does not support restrictions (but can be mirrored to ECR Private),
  #  see https://github.com/aws/containers-roadmap/issues/1609
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
      # Base OS components
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${local.bottlerocket_ecr_image_accounts_lookup[data.aws_region.current.name]}:repository/bottlerocket-control",
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${local.bottlerocket_ecr_image_accounts_lookup[data.aws_region.current.name]}:repository/bottlerocket-admin",
      # Base EKS components
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${local.eks_ecr_image_accounts_lookup[data.aws_region.current.name]}:repository/amazon-k8s-cni-init",
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${local.eks_ecr_image_accounts_lookup[data.aws_region.current.name]}:repository/amazon-k8s-cni",
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${local.eks_ecr_image_accounts_lookup[data.aws_region.current.name]}:repository/eks/kube-proxy",
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${local.eks_ecr_image_accounts_lookup[data.aws_region.current.name]}:repository/eks/coredns",
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${local.eks_ecr_image_accounts_lookup[data.aws_region.current.name]}:repository/eks/pause-amd64",
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${local.eks_ecr_image_accounts_lookup[data.aws_region.current.name]}:repository/eks/pause-arm64",
      # Apps
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/test-app-2022",
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/kube-eventer",
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
}

resource "aws_iam_policy" "eks_ec2_workers" {
  name        = "${local.cluster_name}-ec2-workers"
  description = "A policy that gives basic IAM rights to the EC2 workers for EKS"

  policy = data.aws_iam_policy_document.eks_ec2_workers.json
}

data "aws_iam_policy_document" "eks_ec2_workers_assume_role_policy" {
  statement {
    sid     = "EKSNodeAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.${data.aws_partition.current.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "eks_ec2_workers" {
  name        = "${local.cluster_name}-ec2-workers"
  description = "An IAM Role that is assumed by EC2 workers for EKS"

  assume_role_policy    = data.aws_iam_policy_document.eks_ec2_workers_assume_role_policy.json
  force_detach_policies = true

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "attach_eks_ec2_workers_permissions" {
  role       = aws_iam_role.eks_ec2_workers.name
  policy_arn = aws_iam_policy.eks_ec2_workers.arn
}

# Even though these policies are already included, we are forced to attach them
# See https://github.com/aws/containers-roadmap/issues/1610
resource "aws_iam_role_policy_attachment" "attach_eks_ec2_workers_permissions_hardcoded_one" {
  role       = aws_iam_role.eks_ec2_workers.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "attach_eks_ec2_workers_permissions_hardcoded_two" {
  role       = aws_iam_role.eks_ec2_workers.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
