resource "aws_vpc" "main" {
  cidr_block = var.cidr_block

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "sub_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_a_cidr
  availability_zone       = var.aws_region_az_a
  map_public_ip_on_launch = true

  tags = {
    Name = "sub_a"
  }
}

resource "aws_subnet" "sub_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_b_cidr
  availability_zone       = var.aws_region_az_b
  map_public_ip_on_launch = true

  tags = {
    Name = "sub_b"
  }
}