module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "v2.33.2"

  function_name = "my-lambda1"
  description   = "My awesome lambda function"
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  timeout       = 30

  source_path       = "./src"
  build_in_docker   = true
  docker_build_root = "."
  docker_image      = "lambci/lambda:build-python3.8"

  publish = true
  allowed_triggers = {
    AllowExecutionFromAPIGateway = {
      service    = "apigateway"
      source_arn = "${module.api_gateway.apigatewayv2_api_execution_arn}/*/*"
    }
  }

  tags = local.tags
}
