module "aws_vpc_cni_pod_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.8.0"

  create_role      = true
  role_name        = "${local.cluster_name}-irsa-aws-vpc-cni"
  role_description = "IRSA role for aws-vpc-cni"

  provider_url                   = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  role_policy_arns               = [aws_iam_policy.aws_vpc_cni.arn]
  oidc_fully_qualified_subjects  = ["system:serviceaccount:kube-system:aws-node"]
  oidc_fully_qualified_audiences = ["sts.${data.aws_partition.current.dns_suffix}"]

  tags = local.tags
}

resource "aws_iam_policy" "aws_vpc_cni" {
  name   = "${local.cluster_name}-irsa-aws-vpc-cni"
  policy = data.aws_iam_policy_document.aws_vpc_cni.json

  tags = local.tags
}

data "aws_iam_policy_document" "aws_vpc_cni" {
  # Copied from arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy and AmazonEKS_CNI_IPv6_Policy
  # Allow aws-vpc-cni to do its thing
  statement {
    sid = "awsvpccni"
    actions = [
      "ec2:AssignPrivateIpAddresses",
      "ec2:AttachNetworkInterface",
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeInstanceTypes",
      "ec2:DetachNetworkInterface",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:UnassignPrivateIpAddresses",
      "ec2:AssignIpv6Addresses",
    ]
    resources = ["*"]
  }
  statement {
    sid = "awsvpccnitags"
    actions = [
      "ec2:CreateTags",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:ec2:*:*:network-interface/*"]
  }
}
