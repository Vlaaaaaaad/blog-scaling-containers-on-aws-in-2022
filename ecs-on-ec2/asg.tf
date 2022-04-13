resource "aws_launch_template" "ecs" {
  name        = local.cluster_name
  description = "LT for ECS on EC2 testing"

  image_id      = data.aws_ssm_parameter.ecs_bottlerocket.value
  user_data     = filebase64("${path.module}/ec2-ecs-config.toml")
  instance_type = "c6g.4xlarge"
  instance_market_options {
    market_type = "spot"
  }
  instance_initiated_shutdown_behavior = "terminate"
  update_default_version               = true

  ebs_optimized = true
  monitoring {
    enabled = true
  }

  network_interfaces {
    associate_public_ip_address = false
    delete_on_termination       = true
    security_groups = [
      aws_security_group.app.id
    ]
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = "2"
    http_protocol_ipv6          = "disabled"
  }

  key_name = "test"
  iam_instance_profile {
    arn = aws_iam_instance_profile.ecs_instance.arn
  }

  block_device_mappings {
    device_name = "/dev/xvdb"

    ebs {
      volume_type = "gp3"
      volume_size = "30"
    }
  }

  tags = local.tags
}

resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier = module.vpc.private_subnets

  desired_capacity      = null
  max_size              = 250
  min_size              = 1
  protect_from_scale_in = true
  force_delete          = true # Will lead to dangling resources!


  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  metrics_granularity = "1Minute"
  enabled_metrics     = ["GroupDesiredCapacity", "GroupInServiceInstances", "GroupMaxSize", "GroupMinSize", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}
