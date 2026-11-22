module "platform" {
  source              = "../../modules/platform"
  env                 = var.env
  vpc_cidr            = var.vpc_cidr
  admin_user          = var.admin_user
  ssh_public_key_path = var.ssh_public_key_path
  admin_cidrs         = var.admin_cidrs
  servers             = var.servers
}
