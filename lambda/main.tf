terraform {
  required_version = "1.1.4"

  backend "s3" {
    bucket         = "mybucket"
    key            = "2022/lambda/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-table"
  }

  required_providers {
    aws = {
      version = "3.73.0"
      source  = "hashicorp/aws"
    }
    local = {
      version = "2.1.0"
      source  = "hashicorp/local"
    }
  }
}

provider "aws" {
  region                     = "us-east-1"
  skip_requesting_account_id = false
}

locals {
  cluster_name = "lambda"
  tags = {
    "Project" = "lambda"
  }
}

data "aws_partition" "current" {
}

data "aws_region" "current" {
}

data "aws_caller_identity" "current" {
}
