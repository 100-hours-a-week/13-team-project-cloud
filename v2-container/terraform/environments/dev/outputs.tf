# =============================================================================
# Network
# =============================================================================
output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "private_app_subnet_ids" {
  value = module.network.private_app_subnet_ids
}

output "private_data_subnet_ids" {
  value = module.network.private_data_subnet_ids
}

# =============================================================================
# ALB
# =============================================================================
output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "alb_zone_id" {
  value = module.alb.alb_zone_id
}

# =============================================================================
# Instances
# =============================================================================
output "backend_1_private_ip" {
  value = module.compute.backend_1_private_ip
}

output "backend_2_private_ip" {
  value = module.compute.backend_2_private_ip
}

output "recommend_private_ip" {
  value = module.compute.recommend_private_ip
}

output "postgresql_private_ips" {
  value = module.compute.postgresql_private_ips
}

output "redis_private_ips" {
  value = module.compute.redis_private_ips
}

# =============================================================================
# DNS
# =============================================================================
output "internal_zone_id" {
  value = aws_route53_zone.internal.zone_id
}

output "cloudfront_domain_name" {
  value = module.frontend.cloudfront_domain
}

# =============================================================================
# Security Groups
# =============================================================================
output "app_sg_id" {
  value = module.security.app_sg_id
}

output "data_sg_id" {
  value = module.security.data_sg_id
}

# =============================================================================
# ECR
# =============================================================================
output "ecr_backend_url" {
  value = module.ecr.backend_repo_url
}

output "ecr_recommend_url" {
  value = module.ecr.recommend_repo_url
}

# =============================================================================
# OIDC
# =============================================================================
output "github_actions_role_arn" {
  value = module.github_actions.role_arn
}

# =============================================================================
# Frontend
# =============================================================================
output "frontend_s3_bucket" {
  value = module.frontend.s3_bucket_name
}

output "cloudfront_distribution_id" {
  value = module.frontend.cloudfront_id
}

# =============================================================================
# Receipt S3
# =============================================================================
output "receipt_s3_bucket" {
  value = module.receipt_s3.bucket_name
}

output "receipt_s3_bucket_arn" {
  value = module.receipt_s3.bucket_arn
}
