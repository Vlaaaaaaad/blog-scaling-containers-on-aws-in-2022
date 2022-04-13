resource "aws_cloudwatch_log_group" "app" {
  name              = "app-${local.cluster_name}"
  retention_in_days = 60

  tags = local.tags
}

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

resource "aws_ecs_task_definition" "task" {
  family = "appz-${local.cluster_name}"

  runtime_platform {
    # The valid values for Amazon ECS tasks hosted on Fargate are LINUX, WINDOWS_SERVER_2019_FULL, and WINDOWS_SERVER_2019_CORE.
    # The valid values for Amazon ECS tasks hosted on EC2 are LINUX, WINDOWS_SERVER_2022_CORE, WINDOWS_SERVER_2022_FULL, WINDOWS_SERVER_2019_FULL, and WINDOWS_SERVER_2019_CORE, WINDOWS_SERVER_2016_FULL, WINDOWS_SERVER_2004_CORE, and WINDOWS_SERVER_20H2_CORE.
    operating_system_family = "LINUX"
    # operating_system_family = "WINDOWS_SERVER_2019_CORE"
    cpu_architecture = "X86_64" # or ARM64
    # cpu_architecture        = "ARM64"
  }
  # WINDOWS_SERVER_2019_FULL takes 10 minutes to start

  task_role_arn            = aws_iam_role.task_role.arn
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 1024
  memory                   = 2048

  container_definitions = jsonencode([
    {
      name                   = "app"
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
      environment = [
        {
          name  = "VLAAAAAAAD_RUNNER_TYPE"
          value = "fargate"
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
