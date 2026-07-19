# --------------------------------------------------------------------------
# Use an existing VPC and subnets for the EKS cluster
# --------------------------------------------------------------------------

data "aws_vpc" "existing" {
  id = var.vpc_id
}

# Manage the two existing subnets so we can enable public IP on launch
resource "aws_subnet" "imported_a" {
  # matches subnet-0a2360af89c7f9ada
  vpc_id                  = var.vpc_id
  cidr_block              = "10.0.101.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "imported_b" {
  # matches subnet-04e8719e5336b60d6
  vpc_id                  = var.vpc_id
  cidr_block              = "10.0.102.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}
