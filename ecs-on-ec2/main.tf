terraform {
  required_version = "1.1.7"

  backend "s3" {
    bucket         = "mybucket"
    key            = "2022/ecs-on-ec2/terraform.tfstate"
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
  cluster_name = "ecs-on-ec2-yolo"

  services = {
    "onexxx" = 700
    "twoxxx"   = 700
    "threexxx" = 700
    "fourxxx"  = 700
    "fivexxx"  = 700
    # "sixxxx" = 500
    # "sevenxxx" = 500
    # "eightxxx" = 350
    # "ninexxx" = 350
    # "tenxxx" = 350
    # "six" = 1
    # "seven" = 1
    # "eight" = 1
    # "nine" = 1
    # "ten" = 1
    # "one" = 350
    # "two" = 350
    # "three" = 350
    # "four" = 350
    # "five" = 350
    # "six" = 350
    # "seven" = 350
    # "eight" = 350
    # "nine" = 350
    # "ten" = 350
  }
  tags = {
    "Project" = "ecs-on-ec2-cucumber"
  }
}

data "aws_partition" "current" {
}

data "aws_region" "current" {
}

data "aws_caller_identity" "current" {
}

data "aws_ssm_parameter" "ecs_bottlerocket" {
  name = "/aws/service/bottlerocket/aws-ecs-1/arm64/latest/image_id"
}
