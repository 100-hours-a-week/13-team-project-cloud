module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr           = var.vpc_cidr
  vpc_name           = var.vpc_name
  availability_zones = var.availability_zones
  vpc_subnet_cidrs   = var.vpc_subnet_cidrs
  vpc_tags           = var.vpc_tags
}

data "terraform_remote_state" "core" {
  backend = "s3"
  config = {
    bucket = "moyeo-bab-tfstate-dev"
    key    = "environments/dev-core/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "monitoring" {
  backend = "s3"
  config = {
    bucket = "moyeo-bab-tfstate-dev"
    key    = "environments/dev-monitoring/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

module "app_instance" {
  source = "../../modules/ec2"

  name                        = "${var.vpc_name}-app"
  vpc_id                      = module.vpc.vpc_id
  subnet_id                   = module.vpc.subnet_ids[var.ec2_subnet_index]
  tags                        = var.vpc_tags
  ami_id                      = var.ec2_ami_id
  instance_type               = var.ec2_instance_type
  root_volume_size            = var.ec2_root_volume_size
  root_volume_type            = var.ec2_root_volume_type
  db_volume_id                = data.terraform_remote_state.core.outputs.db_volume_id
  db_device_name              = var.ec2_db_device_name
  associate_public_ip_address = var.ec2_associate_public_ip_address
  eip_allocation_id           = data.terraform_remote_state.core.outputs.eip_allocation_id
  key_name                    = var.ec2_key_name
  ssh_cidrs                   = var.ec2_ssh_cidrs
  http_cidrs                  = var.ec2_http_cidrs
  wireguard_cidrs             = var.ec2_wireguard_cidrs
  private_ip                  = var.ec2_private_ip
  monitoring_security_group_id = data.terraform_remote_state.monitoring.outputs.monitoring_security_group_id
}
