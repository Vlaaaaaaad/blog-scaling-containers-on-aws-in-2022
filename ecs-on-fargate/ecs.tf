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
    "FARGATE_SPOT",
  ]

  default_capacity_provider_strategy {
    base              = 0
    weight            = 100
    capacity_provider = "FARGATE_SPOT"
  }
}

resource "aws_ecs_service" "service" {
  for_each = local.services

  name            = "${each.key}-${local.cluster_name}"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = each.value

  # launch_type      = "FARGATE"
  # platform_version = "1.0.0" # Windows
  # platform_version = "1.4.0" # Linux

  capacity_provider_strategy {
    base              = 0
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }

  network_configuration {
    assign_public_ip = false
    subnets          = module.vpc.private_subnets
    security_groups = [
      aws_security_group.app.id,
    ]
  }
}
