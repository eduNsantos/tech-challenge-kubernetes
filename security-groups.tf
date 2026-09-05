
resource "aws_security_group" "rds" {
  name        = "rds"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "rds"
  }
}

resource "aws_security_group" "eks" {
  name        = "eks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "eks"
  }
}

resource "aws_vpc_security_group_ingress_rule" "eks" {
  security_group_id            = aws_security_group.eks.id
  cidr_ipv4 = var.cidr_block

  ip_protocol = "-1"
}

resource "aws_vpc_security_group_egress_rule" "eks" {
  security_group_id            = aws_security_group.eks.id
  cidr_ipv4 = var.cidr_block

  ip_protocol = "-1"
}

resource "aws_vpc_security_group_ingress_rule" "allow_app_my_ip" {
  security_group_id = aws_security_group.eks.id
  cidr_ipv4         = "179.98.123.83/32"
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "swagger_my_ip" {
  security_group_id = aws_security_group.eks.id
  cidr_ipv4         = "179.98.123.83/32"
  from_port         = 8082
  to_port           = 8082
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "allow_mysql" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.eks.id

  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.rds.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}