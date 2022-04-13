module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.3"

  name                            = local.cluster_name
  enable_ipv6                     = true
  assign_ipv6_address_on_creation = true

  azs = [
    "use1-az1",
    "use1-az4",
    "use1-az5",
    "use1-az6",
  ]

  cidr = "172.16.0.0/16"
  secondary_cidr_blocks = [
    "172.17.0.0/16",
    "172.18.0.0/16",
    "172.19.0.0/16",
    "172.20.0.0/16",
  ]

  public_subnet_ipv6_prefixes                   = [0, 1, 2, 3]
  public_subnet_assign_ipv6_address_on_creation = true
  public_subnets = [
    "172.16.32.0/19",
    "172.16.64.0/19",
    "172.16.96.0/19",
    "172.16.128.0/19",
  ]

  private_subnet_ipv6_prefixes                   = [4, 5, 6, 7]
  private_subnet_assign_ipv6_address_on_creation = true
  private_subnets = [
    "172.17.0.0/16",
    "172.18.0.0/16",
    "172.19.0.0/16",
    "172.20.0.0/16",
  ]

  enable_dns_support   = true
  enable_dns_hostnames = true

  # No NAT Gateway
  enable_nat_gateway     = true
  create_egress_only_igw = true
  one_nat_gateway_per_az = true
  single_nat_gateway     = false

  vpc_tags = local.tags
  private_subnet_tags = merge(
    local.tags,
    {
      "kubernetes.io/cluster/${local.cluster_name}" = ""
    },
    {
      "kubernetes.io/role/internal-elb" = "1"
    },
    {
      "karpenter-yas" = "yas"
    },
  )
  public_subnet_tags = merge(
    local.tags,
    {
      "kubernetes.io/cluster/${local.cluster_name}" = ""
    },
    {
      "kubernetes.io/role/elb" = "1"
    },
  )
  tags = local.tags
}

module "endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "3.11.3"

  vpc_id = module.vpc.vpc_id
  security_group_ids = [
    aws_security_group.vpc_endpoints.id
  ]

  endpoints = {
    s3 = {
      service      = "s3"
      service_type = "Gateway"
      route_table_ids = flatten([
        module.vpc.default_route_table_id,
        module.vpc.private_route_table_ids,
        module.vpc.public_route_table_ids,
      ])
      policy = data.aws_iam_policy_document.s3_endpoint_policy.json
    },
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      policy              = data.aws_iam_policy_document.ecr_endpoint_policy.json
    },
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      policy              = data.aws_iam_policy_document.ecr_endpoint_policy.json
    },
  }


  tags = local.tags
}

data "aws_iam_policy_document" "ecr_endpoint_policy" {
  # Allow ECR Private and ECR Public login
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr-public:GetAuthorizationToken",
      "sts:GetServiceBearerToken",
    ]
    resources = [
      "*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  # Only allow ECR pulls from a specific repos
  statement {
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

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

data "aws_iam_policy_document" "s3_endpoint_policy" {
  # Only allow S3 access for ECR and Dockerhub
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      # ECR S3 bucket, see https://docs.aws.amazon.com/AmazonECR/latest/userguide/vpc-endpoints.html#ecr-setting-up-s3-gateway
      "arn:${data.aws_partition.current.partition}:s3:::prod-${data.aws_region.current.name}-starport-layer-bucket/*",
      # Dockerhub S3 bucket, see https://github.com/docker/hub-feedback/issues/1318
      "arn:${data.aws_partition.current.partition}:s3:::docker-images-prod/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_security_group" "vpc_endpoints" {
  name = format("%.255s", "${local.cluster_name}_vpc_endpoints")
  description = format(
    "%.255s",
    "Terraform-managed SG for VPC Endpoints in ${local.cluster_name}",
  )
  vpc_id = module.vpc.vpc_id

  tags = local.tags
}

resource "aws_security_group_rule" "vpc_endpoints_from_ondemand" {
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = "Allow traffic from EC2: the OnDemand EKS Managed Node Group"

  type      = "ingress"
  protocol  = "all"
  from_port = 0
  to_port   = 0

  source_security_group_id = module.eks.eks_managed_node_groups.ondemand.security_group_id
}

resource "aws_security_group_rule" "vpc_endpoints_from_spot" {
  security_group_id = aws_security_group.vpc_endpoints.id
  description       = "Allow traffic from EC2: the Spot EKS Managed Node Group"

  type      = "ingress"
  protocol  = "all"
  from_port = 0
  to_port   = 0

  source_security_group_id = module.eks.eks_managed_node_groups.spot.security_group_id
}
