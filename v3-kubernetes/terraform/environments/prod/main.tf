# =============================================================================
# Security — K8s SG + 기존 Data SG에 인바운드 규칙 추가
# =============================================================================
module "security" {
  source = "../../modules/security"

  project     = local.project
  environment = local.environment
  app_version = local.version
  common_tags = local.common_tags
  vpc_id      = data.aws_vpc.existing.id

  data_sg_id        = data.aws_security_group.data.id
  admin_cidr_blocks = var.admin_cidr_blocks
}

# =============================================================================
# IAM — K8s 노드 Role + Instance Profile
# =============================================================================
module "iam" {
  source = "../../modules/iam"

  project     = local.project
  environment = local.environment
  app_version = local.version
  common_tags = local.common_tags
  region      = var.region
  account_id  = data.aws_caller_identity.current.account_id
}

# =============================================================================
# Compute — Control Plane EC2 인스턴스 (고정 IP)
# =============================================================================
module "compute" {
  source = "../../modules/compute"

  project     = local.project
  environment = local.environment
  app_version = local.version
  common_tags = local.common_tags

  ec2_ami_id            = var.ec2_ami_id
  instance_profile_name = module.iam.k8s_node_instance_profile_name
  subnet_id             = data.aws_subnet.app_primary.id
  k8s_node_sg_id        = module.security.k8s_node_sg_id
  k8s_cp_sg_id          = module.security.k8s_cp_sg_id

  cp_instances = {
    cp = {
      private_ip    = "10.0.1.100"
      instance_type = var.cp_instance_type
    }
  }
}

# =============================================================================
# NLB — Public 서브넷, Traefik NodePort로 라우팅
# =============================================================================
module "nlb" {
  source = "../../modules/nlb"

  project     = local.project
  environment = local.environment
  app_version = local.version
  common_tags = local.common_tags

  vpc_id              = data.aws_vpc.existing.id
  public_subnet_ids   = data.aws_subnets.public.ids
  acm_certificate_arn = data.aws_acm_certificate.main.arn
}

# =============================================================================
# ASG — Worker 노드 오토스케일링 (멀티 AZ, NLB 타겟그룹 자동 등록)
# =============================================================================
module "asg" {
  source = "../../modules/asg"

  project     = local.project
  environment = local.environment
  app_version = local.version
  common_tags = local.common_tags

  ec2_ami_id            = var.ec2_ami_id
  instance_type         = var.wp_instance_type
  instance_profile_name = module.iam.k8s_node_instance_profile_name
  subnet_ids            = data.aws_subnets.app.ids
  k8s_node_sg_id        = module.security.k8s_node_sg_id
  deploy_env            = local.environment
  region                = var.region
  account_id            = data.aws_caller_identity.current.account_id

  target_group_arns = [
    module.nlb.http_target_group_arn,
  ]

  desired_capacity = var.wp_asg_desired
  min_size         = var.wp_asg_min
  max_size         = var.wp_asg_max
}

# =============================================================================
# Data Services — MongoDB + RabbitMQ EC2 (Data tier 서브넷)
# =============================================================================
module "data_services" {
  source = "../../modules/data-services"

  project     = local.project
  environment = local.environment
  app_version = local.version
  common_tags = local.common_tags

  vpc_id                = data.aws_vpc.existing.id
  subnet_id             = data.aws_subnet.data_primary.id
  data_sg_id            = data.aws_security_group.data.id
  ec2_ami_id            = data.aws_ami.ubuntu_arm.id
  instance_profile_name = module.iam.k8s_node_instance_profile_name

  rabbitmq_instance_type = var.rabbitmq_instance_type
  rabbitmq_user          = var.rabbitmq_user
  rabbitmq_password      = var.rabbitmq_password

  mongodb_instance_type  = var.mongodb_instance_type
  mongodb_admin_user     = var.mongodb_admin_user
  mongodb_admin_password = var.mongodb_admin_password
}
