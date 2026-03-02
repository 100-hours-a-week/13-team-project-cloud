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

  ec2_ami_id             = var.ec2_ami_id
  private_app_subnet_id  = module.network.private_app_subnet_ids[0]
  app_sg_id              = module.security.app_sg_id
  app_monitoring_sg_id   = module.security.app_monitoring_sg_id
  data_sg_id             = module.security.data_sg_id
  data_monitoring_sg_id  = module.security.data_monitoring_sg_id

  postgresql_instances = {
    primary = {
      subnet_id = module.network.private_data_subnet_ids[0]
    }
  }

  redis_instances = {
    primary = {
      subnet_id = module.network.private_data_subnet_ids[0]
    }
  }
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
  enable_path_blocking = var.enable_path_blocking
}

# =============================================================================
# ASG — Backend (Auto Scaling Group)
# NOTE: target group attachment는 ASG가 자동 관리
# =============================================================================
module "backend_asg" {
  source = "../../modules/asg"

  project      = local.project
  environment  = local.environment
  app_version  = local.version
  common_tags  = local.common_tags
  service_name = "backend"
  service_tags = {
    Tier        = "app"
    Service     = "backend"
    ServicePort = "8080"
    MetricsPath = "/actuator/prometheus"
  }

  ami_id                = var.ec2_ami_id
  instance_profile_name = module.compute.ec2_instance_profile_name
  security_group_ids    = compact([module.security.app_sg_id, module.security.app_monitoring_sg_id])

  subnet_ids        = module.network.private_app_subnet_ids
  target_group_arns = [module.alb.target_group_arn]

  user_data = templatefile("${path.module}/../../../scripts/user-data/backend-user-data.sh", {
    deploy_env = local.environment
  })

  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  health_check_type         = "ELB"
  health_check_grace_period = 300
  default_instance_warmup   = 300
}

# =============================================================================
# ASG — Recommend (Auto Scaling Group, desired=1)
# NOTE: target_group_arns 없음 (internal DNS로 접근), EC2 health check
# =============================================================================
module "asg_recommend" {
  source = "../../modules/asg"

  project      = local.project
  environment  = local.environment
  app_version  = local.version
  common_tags  = local.common_tags
  service_name = "recommend"
  service_tags = {
    Tier        = "app"
    Service     = "recommend"
    ServicePort = "8000"
    MetricsPath = "/metrics"
  }

  ami_id                = var.ec2_ami_id
  instance_profile_name = module.compute.ec2_instance_profile_name
  security_group_ids    = compact([module.security.app_sg_id, module.security.app_monitoring_sg_id])

  subnet_ids = [module.network.private_app_subnet_ids[0]]

  user_data = templatefile("${path.module}/../../../scripts/user-data/recommend-user-data.sh", {
    deploy_env = local.environment
  })

  min_size         = 1
  max_size         = 1
  desired_capacity = 1

  health_check_type         = "EC2"
  health_check_grace_period = 300
}

module "ecr" {
  source = "../../modules/ecr"

  project     = local.project
  environment = local.environment
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

module "config_s3" {
  source = "../../modules/config_s3"

  project     = local.project
  environment = local.environment
  common_tags = local.common_tags
  ec2_role_id = module.compute.ec2_role_id
}

module "receipt_s3" {
  source = "../../modules/receipt_s3"

  project     = local.project
  environment = local.environment
  common_tags = local.common_tags
  ec2_role_id = module.compute.ec2_role_id
}

module "parameter_store" {
  source = "../../modules/parameter-store"

  project                   = local.project
  environment               = local.environment
  common_tags               = local.common_tags
  region                    = var.region
  account_id                = data.aws_caller_identity.current.account_id
  ec2_role_id  = module.compute.ec2_role_id
}

module "github_actions" {
  source = "../../modules/github_actions"

  project     = local.project
  environment = local.environment
  common_tags = local.common_tags

  oidc_provider_arn      = data.aws_iam_openid_connect_provider.github.arn
  oidc_subjects          = local.oidc_subjects

  ecr_backend_arn        = module.ecr.backend_repo_arn
  ecr_recommend_arn      = module.ecr.recommend_repo_arn

  frontend_s3_bucket_arn  = module.frontend.s3_bucket_arn
  frontend_cloudfront_arn = module.frontend.cloudfront_arn

  config_s3_bucket_arn   = module.config_s3.bucket_arn
  receipt_s3_bucket_arn  = module.receipt_s3.bucket_arn
  enable_receipt_s3      = true

  region                 = var.region
  account_id             = data.aws_caller_identity.current.account_id
}
