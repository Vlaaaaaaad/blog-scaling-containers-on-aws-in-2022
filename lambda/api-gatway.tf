module "api_gateway" {
  source  = "terraform-aws-modules/apigateway-v2/aws"
  version = "1.5.1"

  name                   = "dev-http"
  description            = "My awesome HTTP API Gateway"
  protocol_type          = "HTTP"
  create_api_domain_name = false

  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }

  default_stage_access_log_destination_arn = aws_cloudwatch_log_group.logs.arn
  default_stage_access_log_format          = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId $context.integrationErrorMessage"

  default_route_settings = {
    detailed_metrics_enabled = true
    throttling_burst_limit   = 0
    throttling_rate_limit    = 0
  }

  # Routes and integrations
  integrations = {
    "ANY /" = {
      lambda_arn             = module.lambda_function.lambda_function_arn
      payload_format_version = "2.0"
      timeout_milliseconds   = 3000
    }

    "$default" = {
      lambda_arn           = module.lambda_function.lambda_function_arn
      timeout_milliseconds = 3000
    }
  }

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "logs" {
  name = "api-gateway-logs"
}
