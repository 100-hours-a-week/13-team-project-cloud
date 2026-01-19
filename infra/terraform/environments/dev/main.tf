module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr           = var.vpc_cidr
  vpc_name           = var.vpc_name
  availability_zones = var.availability_zones
  vpc_subnet_cidrs   = var.vpc_subnet_cidrs
  vpc_tags           = var.vpc_tags
}

module "app_instance" {
  source = "../../modules/ec2-single"

  name             = "${var.vpc_name}-app"
  vpc_id           = module.vpc.vpc_id
  subnet_id        = module.vpc.subnet_ids[var.ec2_subnet_index]
  tags             = var.vpc_tags
  ami_id           = var.ec2_ami_id
  instance_type    = var.ec2_instance_type
  root_volume_size = var.ec2_root_volume_size
  root_volume_type = var.ec2_root_volume_type
  key_name         = var.ec2_key_name
  ssh_cidrs        = var.ec2_ssh_cidrs
  http_cidrs       = var.ec2_http_cidrs
}
