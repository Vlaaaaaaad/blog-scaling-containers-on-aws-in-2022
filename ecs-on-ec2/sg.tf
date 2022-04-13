
resource "aws_security_group" "app" {
  vpc_id = module.vpc.vpc_id
  name   = format("%.255s", "app-${local.cluster_name}")
  description = format(
    "%.255s",
    "Terraform-managed SG for ECS taks from ${local.cluster_name}",
  )

  tags = local.tags
}

resource "aws_security_group_rule" "app_out" {
  security_group_id = aws_security_group.app.id
  description       = "Allow the app to send traffic out to the world"

  type      = "egress"
  protocol  = "all"
  from_port = "0"
  to_port   = "65535"

  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}

# resource "aws_security_group_rule" "app_in" {
#   security_group_id = aws_security_group.app.id
#   description       = "Allow the app to get traffic in from the world"
#
#   type      = "ingress"
#   protocol  = "tcp"
#   from_port = "0"
#   to_port   = "65535"
#
#   cidr_blocks = ["0.0.0.0/0"]
# }
