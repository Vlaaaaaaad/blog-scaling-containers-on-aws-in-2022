terraform {
  required_version = "1.1.7"

  backend "s3" {
    bucket         = "mybucket"
    key            = "2022/ecs-on-fargate/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-table"
  }

  required_providers {
    aws = {
      version = "4.8.0"
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  cluster_name = "ecs-on-fargate"
  services = {
    "one"   = 1
    "two"   = 1
    "three" = 1
    "four"  = 1
    "five"  = 1
  }
  tags = {
    "Project" = "ecs-on-fargate"
  }
}

data "aws_partition" "current" {
}

data "aws_region" "current" {
}

data "aws_caller_identity" "current" {
}
