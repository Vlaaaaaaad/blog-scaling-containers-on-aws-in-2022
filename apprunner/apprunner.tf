resource "aws_apprunner_service" "example" {
  service_name = "myapp"

  source_configuration {
    authentication_configuration {
      access_role_arn = aws_iam_role.access.arn
    }

    image_repository {
      image_configuration {
        port = "5002"
        runtime_environment_variables = {
          VLAAAAAAAD_ORCHESTRATOR_TYPE = "apprunner"
          VLAAAAAAAD_RUNNER_TYPE       = "apprunner"
          AAAA = "bbb"
        }
      }
      image_identifier      = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com/test-app-2022:7fb35066130d89f98c5f0aaf9b9aeb3bc0bdf457"
      image_repository_type = "ECR"
    }
  }

  health_check_configuration {
    healthy_threshold   = 1
    interval            = 3
    path                = "/status/healthy"
    protocol            = "HTTP"
    timeout             = 3
    unhealthy_threshold = 3
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.high.arn
  instance_configuration {
    cpu               = "1 vCPU"
    memory            = "2 GB"
    instance_role_arn = aws_iam_role.instance.arn
  }

  tags = local.tags

  depends_on = [
    aws_iam_role_policy_attachment.attach_permissions_workers,
  ]
}

resource "aws_apprunner_auto_scaling_configuration_version" "low" {
  auto_scaling_configuration_name = "first"

  max_concurrency = 1
  max_size        = 1
  min_size        = 1

  tags = local.tags
}


resource "aws_apprunner_auto_scaling_configuration_version" "high" {
  auto_scaling_configuration_name = "second"

  max_concurrency = 1
  max_size        = 25
  min_size        = 25

  tags = local.tags
}
