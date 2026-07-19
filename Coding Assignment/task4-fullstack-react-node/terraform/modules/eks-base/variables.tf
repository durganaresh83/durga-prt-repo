variable "project_name" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.5.0.0/16"
}

variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}

variable "service_names" {
  type = list(string)
}
