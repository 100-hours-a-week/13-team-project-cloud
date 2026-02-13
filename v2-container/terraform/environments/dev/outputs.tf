# =============================================================================
# Network
# =============================================================================
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  value = aws_subnet.private_app[*].id
}

output "private_data_subnet_ids" {
  value = aws_subnet.private_data[*].id
}

# =============================================================================
# ALB
# =============================================================================
output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_zone_id" {
  value = aws_lb.main.zone_id
}

# =============================================================================
# Instances
# =============================================================================
output "api_private_ip" {
  value = aws_instance.api.private_ip
}

output "recommend_private_ip" {
  value = aws_instance.recommend.private_ip
}

output "postgresql_private_ip" {
  value = aws_instance.postgresql.private_ip
}

output "redis_private_ip" {
  value = aws_instance.redis.private_ip
}

# =============================================================================
# DNS
# =============================================================================
output "internal_zone_id" {
  value = aws_route53_zone.internal.zone_id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.frontend.domain_name
}

# =============================================================================
# Security Groups (v1 monitoring 연동 시 참조)
# =============================================================================
output "app_sg_id" {
  value = aws_security_group.app.id
}

output "data_sg_id" {
  value = aws_security_group.data.id
}

# =============================================================================
# ECR
# =============================================================================
output "ecr_backend_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "ecr_recommend_url" {
  value = aws_ecr_repository.recommend.repository_url
}

# =============================================================================
# OIDC
# =============================================================================
output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}
