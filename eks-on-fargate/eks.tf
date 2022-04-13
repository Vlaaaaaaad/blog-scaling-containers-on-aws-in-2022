module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "v18.0.1"

  cluster_version = "1.21"
  cluster_name    = local.cluster_name

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true
  vpc_id                          = module.vpc.vpc_id
  subnet_ids                      = module.vpc.private_subnets
  enable_irsa                     = true

  cloudwatch_log_group_retention_in_days = "90"
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  # cluster_addons = {}
  cluster_addons = {
    coredns = {
      addon_version     = "v1.8.4-eksbuild.1"
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      addon_version     = "v1.21.2-eksbuild.2"
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      addon_version            = "v1.10.1-eksbuild.1"
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = module.aws_vpc_cni_pod_role.iam_role_arn
    }
  }

  eks_managed_node_groups = {
    ondemand = {
      platform        = "bottlerocket"
      ami_type        = "BOTTLEROCKET_ARM_64"
      capacity_type   = "SPOT"
      instance_types  = ["c6g.4xlarge"]
      disk_size       = 100
      create_iam_role = false
      iam_role_arn    = aws_iam_role.eks_ec2_workers.arn
      # min_size        = 0
      # desired_size    = 0
      # max_size        = 2
      min_size     = 1
      desired_size = 1
      max_size     = 2
    }
  }

  fargate_profiles = {
    one = {
      name = "one"
      selectors = [
        {
          namespace = "fargate"
        },
      ]
      create_iam_role = false
      iam_role_arn    = aws_iam_role.fargate_pod_execution.arn
    }
  }

  tags = local.tags
}

# Add the rules here cause Terraform is cranky
#  see https://github.com/terraform-aws-modules/terraform-aws-eks/pull/1680#issuecomment-994156844
resource "aws_security_group_rule" "eks_ondemand_to_vpc_endpoints" {
  security_group_id = module.eks.eks_managed_node_groups.ondemand.security_group_id
  description       = "Allow traffic to the VPC Endpoints"

  type      = "egress"
  protocol  = "all"
  from_port = 0
  to_port   = 0

  source_security_group_id = aws_security_group.vpc_endpoints.id
}

resource "aws_security_group_rule" "eks_ondemand_to_s3_endpoint" {
  security_group_id = module.eks.eks_managed_node_groups.ondemand.security_group_id
  description       = "Allow traffic to the S3 VPC Endpoint"

  type      = "egress"
  protocol  = "all"
  from_port = 0
  to_port   = 0

  prefix_list_ids = [
    module.endpoints.endpoints["s3"].prefix_list_id,
  ]
}

# resource "aws_security_group_rule" "myapp_to_vpc_endpoints" {
#   security_group_id = module.eks.eks_managed_node_groups.spot.security_group_id
#   description       = "Allow traffic to the VPC Endpoints"
#
#   type      = "egress"
#   protocol  = "all"
#   from_port = 0
#   to_port   = 0
#
#   source_security_group_id = aws_security_group.vpc_endpoints.id
# }
#
# resource "aws_security_group_rule" "myapp_to_s3_endpoint" {
#   security_group_id = module.eks.eks_managed_node_groups.spot.security_group_id
#   description       = "Allow traffic to the S3 VPC Endpoint"
#
#   type      = "egress"
#   protocol  = "all"
#   from_port = 0
#   to_port   = 0
#
#   prefix_list_ids = [
#     module.endpoints.endpoints["s3"].prefix_list_id,
#   ]
# }
#
# resource "aws_security_group_rule" "eks_ondemand_to_myapp" {
#   security_group_id = module.eks.eks_managed_node_groups.spot.security_group_id
#   description       = "Allow traffic to myapp"
#
#   type      = "egress"
#   protocol  = "all"
#   from_port = 0
#   to_port   = 0
#
#   source_security_group_id = aws_security_group.sg_per_pod_myapp.id
# }
