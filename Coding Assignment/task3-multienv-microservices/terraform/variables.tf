variable "aws_region"   { default = "us-east-1" }
variable "vpc_cidr"     { default = "10.2.0.0/16" }
variable "azs"          { default = ["us-east-1a", "us-east-1b"] }
variable "services"     {
  description = "Microservice names, one ECR repo each"
  type        = list(string)
  default     = ["service-a", "service-b"]
}
variable "node_instance_types" { default = ["t3.medium"] }
variable "node_desired_size"   { default = 2 }
variable "node_min_size"       { default = 1 }
variable "node_max_size"       { default = 4 }
