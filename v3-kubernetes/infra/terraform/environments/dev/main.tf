# =============================================================================
# Network — K8s 서브넷 + Route Table (기존 VPC에 추가)
# =============================================================================
module "network" {
  source = "../../modules/network"

  project            = local.project
  environment        = local.environment
  app_version        = local.version
  common_tags        = local.common_tags
  vpc_id             = data.aws_vpc.existing.id
  availability_zones = var.availability_zones
  k8s_subnet_cidrs   = var.k8s_subnet_cidrs
  nat_gateway_ids    = data.aws_nat_gateway.by_az[*].id
}

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
# Compute — Control Plane + Worker EC2 인스턴스
# =============================================================================
module "compute" {
  source = "../../modules/compute"

  project     = local.project
  environment = local.environment
  app_version = local.version
  common_tags = local.common_tags

  ec2_ami_id            = var.ec2_ami_id
  instance_profile_name = module.iam.k8s_node_instance_profile_name
  k8s_subnet_ids        = module.network.k8s_subnet_ids
  k8s_node_sg_id        = module.security.k8s_node_sg_id
  k8s_cp_sg_id          = module.security.k8s_cp_sg_id

  control_plane_instances = {
    cp-1 = {
      subnet_index = 0
      private_ip   = "10.1.10.10"
    }
  }

  worker_instances = {
    worker-1 = {
      subnet_index = 0
      private_ip   = "10.1.10.20"
    }
  }
}
