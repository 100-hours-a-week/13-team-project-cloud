# =============================================================================
# Network (VPC, Subnets, NAT, Route Tables)
# =============================================================================
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
  monitoring_vpc_peering_id = var.vpc_peering_id
  monitoring_vpc_cidr       = "10.1.0.0/16"
}

# =============================================================================
# Compute (EC2 인스턴스 + IAM Role/Profile)
# =============================================================================
module "compute" {
  source = "../../modules/compute"

  project            = local.project
  environment        = local.environment
  app_version        = local.version
  common_tags        = local.common_tags

  ec2_ami_id = var.ec2_ami_id

  private_app_subnet_id = module.network.private_app_subnet_ids[0]

  app_sg_id  = aws_security_group.app.id
  data_sg_id = aws_security_group.data.id

  # Monitoring SG (조건부 — prod-monitoring 배포 후 활성화)
  app_monitoring_sg_id  = var.monitoring_sg_id != "" ? aws_security_group.app_monitoring[0].id : ""
  data_monitoring_sg_id = var.monitoring_sg_id != "" ? aws_security_group.data_monitoring[0].id : ""

  # prod 백엔드는 ASG로 대체
  enable_backend   = false
  enable_backend_2 = false

  # 고정 Private IP (recommend)
  recommend_private_ip = "10.0.1.20"

  postgresql_instances = {
    primary = {
      subnet_id  = module.network.private_data_subnet_ids[0]
      private_ip = "10.0.2.10"
    },
    standby = {
      subnet_id  = module.network.private_data_subnet_ids[1]
      private_ip = "10.0.7.10"
    }
  }

  redis_instances = {
    primary = {
      subnet_id  = module.network.private_data_subnet_ids[0]
      private_ip = "10.0.2.20"
    },
    standby = {
      subnet_id  = module.network.private_data_subnet_ids[1]
      private_ip = "10.0.7.20"
    }
  }
}

# =============================================================================
# ASG — Backend (Auto Scaling Group)
# =============================================================================
module "asg_backend" {
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

  ami_id = var.ec2_ami_id
  instance_profile_name = module.compute.ec2_instance_profile_name

  security_group_ids = compact([
    aws_security_group.app.id,
    var.monitoring_sg_id != "" ? aws_security_group.app_monitoring[0].id : "",
  ])

  subnet_ids        = module.network.private_app_subnet_ids
  target_group_arns = [aws_lb_target_group.backend.arn]

  user_data = file("${path.module}/../../../scripts/user-data/backend-user-data.sh")

  min_size         = 2
  max_size         = 2
  desired_capacity = 2

  health_check_type         = "ELB"
  health_check_grace_period = 300
}

# =============================================================================
# ECR (컨테이너 이미지 레지스트리)
# =============================================================================
module "ecr" {
  source = "../../modules/ecr"

  project     = local.project
  environment = local.environment
  common_tags = local.common_tags
}

# =============================================================================
# Frontend (S3 + CloudFront)
# =============================================================================
module "frontend" {
  source = "../../modules/frontend"

  project             = local.project
  environment         = local.environment
  common_tags         = local.common_tags
  region              = var.region
  acm_certificate_arn = data.aws_acm_certificate.cloudfront.arn
  domain_alias        = "moyeobab.com"
}

# =============================================================================
# GitHub Actions (OIDC + IAM)
# =============================================================================
module "github_actions" {
  source = "../../modules/github_actions"

  project     = local.project
  environment = local.environment
  common_tags = local.common_tags

  oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
  oidc_subjects     = local.oidc_subjects

  ecr_backend_arn   = module.ecr.backend_repo_arn
  ecr_recommend_arn = module.ecr.recommend_repo_arn

  frontend_s3_bucket_arn  = module.frontend.s3_bucket_arn
  frontend_cloudfront_arn = module.frontend.cloudfront_arn

  config_s3_bucket_arn  = module.config_s3.bucket_arn
  receipt_s3_bucket_arn = module.receipt_s3.bucket_arn
  enable_receipt_s3     = true

  region     = var.region
  account_id = data.aws_caller_identity.current.account_id
}

# =============================================================================
# Config S3 (docker-compose, promtail 등 배포 설정)
# =============================================================================
module "config_s3" {
  source = "../../modules/config_s3"

  project     = local.project
  environment = local.environment
  common_tags = local.common_tags
  ec2_role_id = module.compute.ec2_role_id
}

# =============================================================================
# Parameter Store (SSM 환경변수)
# =============================================================================
module "parameter_store" {
  source = "../../modules/parameter-store"

  project                  = local.project
  environment              = local.environment
  common_tags              = local.common_tags
  region                   = var.region
  account_id               = data.aws_caller_identity.current.account_id
  ec2_role_id  = module.compute.ec2_role_id
}

# =============================================================================
# Receipt S3 (영수증 이미지)
# =============================================================================
module "receipt_s3" {
  source = "../../modules/receipt_s3"

  project     = local.project
  environment = local.environment
  common_tags = local.common_tags
  ec2_role_id = module.compute.ec2_role_id
}
