resource "aws_iam_instance_profile" "karpenter" {
  role = aws_iam_role.eks_ec2_workers.name
  name = "${local.cluster_name}-instance-profile-thingie"

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}


resource "aws_launch_template" "karpenter" {
  name        = "${local.cluster_name}-karpenter-lt"
  description = "Launch Template to be used by Karpenter running in ${local.cluster_name}"


  image_id = "ami-03e82473d6c3e7905" # TODO: this should really not be hardcoded
  vpc_security_group_ids = [         # TODO: some of these are definitely not needed
    module.eks.eks_managed_node_groups.spot.security_group_id,
    module.eks.cluster_primary_security_group_id,
    module.eks.node_security_group_id,
  ]
  user_data = base64encode(
    <<TOML
      [settings.kubernetes]
      "cluster-name" = "${local.cluster_name}"
      "api-server" = "${module.eks.cluster_endpoint}"
      "cluster-certificate" = "${module.eks.cluster_certificate_authority_data}"
      "cluster-dns-ip" = "fd95:f79d:929b::a"
      "max-pods" = 110
    TOML
  )

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      delete_on_termination = true
      volume_type           = "gp3"
      volume_size           = 30
    }
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.karpenter.arn
  }

  #   dynamic "instance_market_options" {
  #     for_each = var.instance_market_options != null ? [var.instance_market_options] : []
  #     content {
  #       market_type = instance_market_options.value.market_type
  #
  #       dynamic "spot_options" {
  #         for_each = lookup(instance_market_options.value, "spot_options", null) != null ? [instance_market_options.value.spot_options] : []
  #         content {
  #           block_duration_minutes         = spot_options.value.block_duration_minutes
  #           instance_interruption_behavior = lookup(spot_options.value, "instance_interruption_behavior", null)
  #           max_price                      = lookup(spot_options.value, "max_price", null)
  #           spot_instance_type             = lookup(spot_options.value, "spot_instance_type", null)
  #           valid_until                    = lookup(spot_options.value, "valid_until", null)
  #         }
  #       }
  #     }
  #   }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = "2"
    http_protocol_ipv6          = "enabled"
  }

  monitoring {
    enabled = true
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}
