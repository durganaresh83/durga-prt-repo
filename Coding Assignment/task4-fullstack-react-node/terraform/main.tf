terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
  # This repo targets the existing microservices-dev cluster for deployment.
  # Use a local state file here to avoid requiring a shared S3 backend for this demo.
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = "us-east-1"
}

module "eks_base" {
  source        = "./modules/eks-base"
  project_name  = "fullstack-react-node"
  service_names = ["frontend", "backend"]
}

output "cluster_name"       { value = module.eks_base.cluster_name }
output "ecr_repository_urls" { value = module.eks_base.ecr_repository_urls }
