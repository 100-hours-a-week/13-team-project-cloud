data "terraform_remote_state" "dev" {
  backend = "s3"
  config = {
    bucket = "moyeo-bab-tfstate-prod"
    key    = "environments/prod/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

module "monitoring_instance" {
  source = "../../modules/monitoring"

  name                        = var.monitoring_name
  vpc_id                      = data.terraform_remote_state.dev.outputs.vpc_id
  subnet_id                   = data.terraform_remote_state.dev.outputs.subnet_ids[var.monitoring_subnet_index]
  tags                        = var.monitoring_tags
  ami_id                      = var.monitoring_ami_id
  instance_type               = var.monitoring_instance_type
  root_volume_size            = var.monitoring_root_volume_size
  root_volume_type            = var.monitoring_root_volume_type
  associate_public_ip_address = var.monitoring_associate_public_ip_address
  key_name                    = var.monitoring_key_name
  ssh_cidrs                   = var.monitoring_ssh_cidrs
  app_security_group_id       = data.terraform_remote_state.dev.outputs.app_security_group_id
  loki_cidrs                  = var.monitoring_loki_cidrs
}
