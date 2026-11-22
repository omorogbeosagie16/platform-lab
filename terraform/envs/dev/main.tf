module "platform" {
  source              = "../../modules/platform"
  env                 = var.env
  vpc_cidr            = var.vpc_cidr
  admin_user          = var.admin_user
  ssh_public_key_path = var.ssh_public_key_path
  admin_cidrs         = var.admin_cidrs
  servers             = var.servers
}

# moved blocks: rename the entries in state so Terraform does not destroy and recreate.
moved {
  from = aws_vpc.this
  to   = module.platform.aws_vpc.this
}

moved {
  from = aws_internet_gateway.this
  to   = module.platform.aws_internet_gateway.this
}

moved {
  from = aws_subnet.public
  to   = module.platform.aws_subnet.public
}

moved {
  from = aws_route_table.public
  to   = module.platform.aws_route_table.public
}

moved {
  from = aws_route_table_association.public
  to   = module.platform.aws_route_table_association.public
}

moved {
  from = aws_security_group.base
  to   = module.platform.aws_security_group.base
}

moved {
  from = aws_vpc_security_group_ingress_rule.ssh
  to   = module.platform.aws_vpc_security_group_ingress_rule.ssh
}

moved {
  from = aws_vpc_security_group_ingress_rule.k8s_api
  to   = module.platform.aws_vpc_security_group_ingress_rule.k8s_api
}

moved {
  from = aws_vpc_security_group_ingress_rule.http
  to   = module.platform.aws_vpc_security_group_ingress_rule.http
}

moved {
  from = aws_vpc_security_group_ingress_rule.https
  to   = module.platform.aws_vpc_security_group_ingress_rule.https
}

moved {
  from = aws_vpc_security_group_ingress_rule.intra_vpc
  to   = module.platform.aws_vpc_security_group_ingress_rule.intra_vpc
}

moved {
  from = aws_vpc_security_group_egress_rule.all
  to   = module.platform.aws_vpc_security_group_egress_rule.all
}

moved {
  from = aws_key_pair.lab
  to   = module.platform.aws_key_pair.lab
}

moved {
  from = aws_instance.this
  to   = module.platform.aws_instance.this
}
