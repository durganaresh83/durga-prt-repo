variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project/prefix name used for tagging and naming resources"
  type        = string
  default     = "durga-prt-flask-eks-demo"
}

variable "vpc_id" {
  description = "Existing VPC ID for the EKS cluster"
  type        = string
  default     = "vpc-0f6478cf22f8a5021"
}

variable "subnet_ids" {
  description = "Existing subnet IDs to use for EKS cluster and nodes"
  type        = list(string)
  default = [
    "subnet-0a2360af89c7f9ada",
    "subnet-04e8719e5336b60d6",
  ]
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.36"
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 4
}
