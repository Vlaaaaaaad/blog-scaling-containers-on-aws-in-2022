terraform {
  required_version = "1.1.6"

  backend "s3" {
    bucket         = "mybucket"
    key            = "2022/apprunner/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-table"
  }

  required_providers {
    aws = {
      version = "4.2.0"
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  cluster_name = "apprunner"
  tags = {
    "Project" = "apprunner"
  }
}

data "aws_partition" "current" {
}

data "aws_region" "current" {
}

data "aws_caller_identity" "current" {
}
