module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.11.0"

  name = local.cluster_name

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
  public_subnets = [
    "172.16.32.0/19",
    "172.16.64.0/19",
    "172.16.96.0/19",
    "172.16.128.0/19",
  ]
  private_subnets = [
    "172.17.0.0/16",
    "172.18.0.0/16",
    "172.19.0.0/16",
    "172.20.0.0/16",
  ]

  enable_dns_support   = true
  enable_dns_hostnames = true

  # One NAT Gateway per AZ
  enable_nat_gateway     = true
  one_nat_gateway_per_az = true
  single_nat_gateway     = false

  vpc_tags            = local.tags
  private_subnet_tags = local.tags
  public_subnet_tags  = local.tags
  tags                = local.tags
}

module "endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "3.11.0"

  vpc_id = module.vpc.vpc_id
  security_group_ids = [
    aws_security_group.vpc_endpoints_in_n_out.id
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
  # Allow ECR login
  statement {
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = [
      "*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }

  # Only allow ECR pulls from a specific repo
  statement {
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/test-app-2022",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

data "aws_iam_policy_document" "s3_endpoint_policy" {
  # Only allow S3 access for ECR
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::prod-${data.aws_region.current.name}-starport-layer-bucket/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }
  }
}

resource "aws_security_group" "vpc_endpoints_in_n_out" {
  name = format("%.255s", "vpc_endpoints_${local.cluster_name}")
  description = format(
    "%.255s",
    "Terraform-managed SG for VPC Endpoints in ${local.cluster_name}",
  )
  vpc_id = module.vpc.vpc_id

  tags = local.tags
}

resource "aws_security_group_rule" "vpc_endpoints_in_spot" {
  security_group_id = aws_security_group.vpc_endpoints_in_n_out.id
  description       = "Allow traffic to the ECR VPC Endpoints"

  type      = "ingress"
  protocol  = "all"
  from_port = 0
  to_port   = 0

  source_security_group_id = aws_security_group.app.id
}

resource "aws_security_group_rule" "vpc_endpoints_out_spot" {
  security_group_id = aws_security_group.vpc_endpoints_in_n_out.id
  description       = "Allow traffic out from the ECR VPC Endpoints"

  type      = "egress"
  protocol  = "all"
  from_port = 0
  to_port   = 0

  source_security_group_id = aws_security_group.app.id
}
