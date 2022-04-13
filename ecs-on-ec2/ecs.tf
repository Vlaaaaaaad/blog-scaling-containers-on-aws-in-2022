resource "aws_ecs_cluster" "cluster" {
  name = local.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_ecs_cluster_capacity_providers" "cps" {
  cluster_name = aws_ecs_cluster.cluster.name

  capacity_providers = [
    aws_ecs_capacity_provider.autoscaling_group.name,
  ]

  default_capacity_provider_strategy {
    base              = 0
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.autoscaling_group.name
  }
}

resource "aws_ecs_capacity_provider" "autoscaling_group" {
  name = "yolo"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.asg.arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      instance_warmup_period    = 1
      maximum_scaling_step_size = null
      minimum_scaling_step_size = null
      target_capacity           = 95
      status                    = "ENABLED"
    }
  }

  tags = local.tags
}

resource "aws_ecs_service" "app" {
  for_each = local.services

  cluster       = aws_ecs_cluster.cluster.id
  name          = "${each.key}-${local.cluster_name}"
  desired_count = each.value

  task_definition = aws_ecs_task_definition.task.arn


  capacity_provider_strategy {
    base              = 0
    capacity_provider = aws_ecs_capacity_provider.autoscaling_group.name
    weight            = 100
  }

  network_configuration {
    assign_public_ip = false
    subnets          = module.vpc.private_subnets
    security_groups = [
      aws_security_group.app.id,
    ]
  }

  tags = local.tags
}
