
variable "cidr_block" {
  type = string
  default = "10.0.0.0/16"
}

variable "aws_region" {
  type = string
  default = "us-east-1"
}

variable "aws_region_az_a" {
  type = string
  default = "us-east-1a"
}

variable "aws_region_az_b" {
  type = string
  default = "us-east-1b"
}

variable "subnet_a_cidr" {
  type = string
  default = "10.0.1.0/24"
}

variable "subnet_b_cidr" {
  type = string
  default = "10.0.2.0/24"
}