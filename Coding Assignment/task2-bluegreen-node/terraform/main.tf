# --------------------------------------------------------------------------
# Task 2: EKS cluster for Blue-Green Node.js deployments (Helm-managed)
# Mirrors the VPC/EKS pattern from Task 1; kept in one file for brevity.
# --------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region"   { default = "us-east-1" }
variable "cluster_name" { default = "durga-prt-flask-eks-demo" }
variable "ecr_repo_name" { default = "durga-prt-flask-eks-demo-app" }

# Use existing EKS cluster and ECR repository
data "aws_eks_cluster" "existing" {
  name = var.cluster_name
}

data "aws_ecr_repository" "existing" {
  name = var.ecr_repo_name
}

output "cluster_name" {
  value = data.aws_eks_cluster.existing.name
}

output "ecr_repository_url" {
  value = data.aws_ecr_repository.existing.repository_url
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${data.aws_eks_cluster.existing.name}"
}
