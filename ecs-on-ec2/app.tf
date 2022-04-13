resource "aws_cloudwatch_log_group" "app" {
  name              = "app-${local.cluster_name}"
  retention_in_days = 60

  tags = local.tags
}

resource "aws_ecs_task_definition" "task" {
  family = "app-${local.cluster_name}"

  # runtime_platform {
  #   operating_system_family = "LINUX"
  #   cpu_architecture        = "ARM64"
  # }

  task_role_arn      = aws_iam_role.task_role.arn
  execution_role_arn = aws_iam_role.task_execution_role.arn
  network_mode       = "awsvpc"
  # requires_compatibilities = ["EC2"]
  cpu    = 1024
  memory = 2048

  container_definitions = jsonencode([
    {
      name                   = "app-yolo"
      image                  = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/test-app-2022:241ac4b1c44fce7e1754b587a6c589204a7be92a"
      cpu                    = 1024
      memory                 = 2048
      essential              = true
      privileged             = false
      readonlyRootFilesystem = false # Python!
      portMappings = [
        {
          containerPort = 5003
          hostPort      = null
        }
      ]
      # TODO: add user to the docker image and here
      # TODO: curl is missing from ubuntu:focal
      # healthcheck = {
      #   command = [
      #     "CMD-SHELL",
      #     "curl -f http://localhost/status/alive || exit 1"
      #   ]
      #   interval    = 5
      #   retries     = 10
      #   startPeriod = 5
      #   timeout     = 3
      # }
      environment = [
        {
          name  = "VLAAAAAAAD_RUNNER_TYPE"
          value = "ec2"
        },
        {
          name  = "VLAAAAAAAD_ORCHESTRATOR_TYPE"
          value = "ecs"
        },
        {
          name  = "VLAAAAAAAD_ECS_SERVICE_COUNT"
          value = tostring(length(local.services))
        },
      ]
      logConfiguration = {
        logDriver = "awslogs"

        options = {
          awslogs-region        = data.aws_region.current.name
          awslogs-group         = aws_cloudwatch_log_group.app.name
          awslogs-stream-prefix = local.cluster_name
        }
      }
    },
  ])
}
