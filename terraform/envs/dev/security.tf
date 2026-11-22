resource "aws_security_group" "base" {
  name_prefix = "${var.env}-base-"
  description = "Base access for lab servers"
  vpc_id      = aws_vpc.this.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each          = toset(var.admin_cidrs)
  security_group_id = aws_security_group.base.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "k8s_api" {
  for_each          = toset(var.admin_cidrs)
  security_group_id = aws_security_group.base.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 6443
  to_port           = 6443
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.base.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.base.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

# Everything inside the VPC may talk (metrics 9100, logs 9200, k3s). Lab simplification.
resource "aws_vpc_security_group_ingress_rule" "intra_vpc" {
  security_group_id = aws_security_group.base.id
  cidr_ipv4         = aws_vpc.this.cidr_block
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.base.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
