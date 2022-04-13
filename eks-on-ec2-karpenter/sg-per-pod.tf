resource "aws_security_group" "sg_per_pod_all" {
  name = format("%.255s", "${local.cluster_name}_sg_per_pod_all")
  description = format(
    "%.255s",
    "Terraform-managed base SG for all pods in ${local.cluster_name}",
  )
  vpc_id = module.vpc.vpc_id

  tags = local.tags
}

resource "aws_security_group_rule" "sg_per_pod_all_to_vpc_endpoints" {
  security_group_id = aws_security_group.sg_per_pod_all.id
  description       = "Allow traffic to the VPC Endpoints"

  type      = "egress"
  protocol  = "all"
  from_port = 0
  to_port   = 0

  source_security_group_id = aws_security_group.vpc_endpoints.id
}

resource "aws_security_group_rule" "sg_per_pod_all_to_ec2_workers" {
  security_group_id = aws_security_group.sg_per_pod_all.id
  description       = "Allow traffic to all EC2 worker nodes (CoreDNS)"

  type      = "egress"
  protocol  = "all"
  from_port = 0
  to_port   = 0

  source_security_group_id = module.eks.node_security_group_id
}

resource "aws_security_group_rule" "sg_per_pod_all_to_eks" {
  security_group_id = aws_security_group.sg_per_pod_all.id
  description       = "Allow traffic to the EKS Control Plane"

  type      = "egress"
  protocol  = "all"
  from_port = 0
  to_port   = 0

  source_security_group_id = module.eks.cluster_security_group_id
}

resource "aws_security_group_rule" "sg_per_pod_all_from_eks" {
  security_group_id = aws_security_group.sg_per_pod_all.id
  description       = "Allow traffic from the EKS Control Plane"

  type      = "ingress"
  protocol  = "all"
  from_port = 0
  to_port   = 0

  source_security_group_id = module.eks.cluster_security_group_id
}
