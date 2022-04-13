terraform {
  required_version = "1.1.2"

  backend "s3" {
    bucket         = "mybucket"
    key            = "2022/eks-on-fargate/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock-table"
  }

  required_providers {
    aws = {
      version = "3.70.0"
      source  = "hashicorp/aws"
    }
    local = {
      version = "2.1.0"
      source  = "hashicorp/local"
    }
    kubernetes = {
      version = "2.7.1"
      source  = "hashicorp/kubernetes"
    }
    helm = {
      version = "2.4.1"
      source  = "hashicorp/helm"
    }
    cloudinit = {
      version = "2.2.0"
      source  = "hashicorp/cloudinit"
    }
    tls = {
      version = "3.1.0"
      source  = "hashicorp/tls"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_eks_cluster_auth" "default" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.default.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.default.token
  }
}

locals {
  cluster_name = "eks-on-fargate"
  tags = {
    "Project" = "eks-on-fargate"
  }
}

data "aws_partition" "current" {
}

data "aws_region" "current" {
}

data "aws_caller_identity" "current" {
}
