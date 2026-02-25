module "network" {
  source = "../../modules/network"

  project                   = local.project
  environment               = local.environment
  app_version               = local.version
  common_tags               = local.common_tags
  vpc_cidr                  = var.vpc_cidr
  availability_zones        = var.availability_zones
  public_subnet_cidrs       = var.public_subnet_cidrs
  private_app_subnet_cidrs  = var.private_app_subnet_cidrs
  private_data_subnet_cidrs = var.private_data_subnet_cidrs
  monitoring_vpc_peering_id = var.monitoring_vpc_peering_id
}

module "security" {
  source = "../../modules/security"

  project     = local.project
  environment = local.environment
  app_version = local.version
  common_tags = local.common_tags
  vpc_id      = module.network.vpc_id
}

module "compute" {
  source = "../../modules/compute"

  project                = local.project
  environment            = local.environment
  app_version            = local.version
  common_tags            = local.common_tags
  service_tags           = local.service_tags
  ec2_ami_id             = var.ec2_ami_id
  ec2_instance_type      = var.ec2_instance_type
  ec2_key_name           = var.ec2_key_name
  private_app_subnet_id  = module.network.private_app_subnet_ids[0]
  private_data_subnet_id = module.network.private_data_subnet_ids[0]
  app_sg_id              = module.security.app_sg_id
  app_monitoring_sg_id   = module.security.app_monitoring_sg_id
  data_sg_id             = module.security.data_sg_id
  data_monitoring_sg_id  = module.security.data_monitoring_sg_id
}

module "alb" {
  source = "../../modules/alb"

  project              = local.project
  environment          = local.environment
  app_version          = local.version
  common_tags          = local.common_tags
  vpc_id               = module.network.vpc_id
  public_subnet_ids    = module.network.public_subnet_ids
  alb_sg_id            = module.security.alb_sg_id
  acm_certificate_arn  = data.aws_acm_certificate.alb.arn
  backend_1_id         = module.compute.backend_1_id
  backend_2_id         = module.compute.backend_2_id
  enable_path_blocking = var.enable_path_blocking
}

module "ecr" {
  source = "../../modules/ecr"

  project     = local.project
  common_tags = local.common_tags
}

module "frontend" {
  source = "../../modules/frontend"

  project             = local.project
  environment         = local.environment
  common_tags         = local.common_tags
  region              = var.region
  acm_certificate_arn = data.aws_acm_certificate.cloudfront.arn
  domain_alias        = "dev.moyeobab.com"
}
