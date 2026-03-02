# =============================================================================
# Private Hosted Zone (VPC 내부 서비스 디스커버리)
# =============================================================================
resource "aws_route53_zone" "internal" {
  name = "internal.dev.moyeobab.com"

  vpc {
    vpc_id = module.network.vpc_id
  }

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-internal-zone"
  })
}

# Internal DNS records
resource "aws_route53_record" "internal_recommend" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "recommend.internal.dev.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = data.aws_instances.recommend.private_ips
}

resource "aws_route53_record" "internal_postgresql" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "db.internal.dev.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [module.compute.postgresql_private_ips["primary"]]
}

resource "aws_route53_record" "internal_redis" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "redis.internal.dev.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [module.compute.redis_private_ips["primary"]]
}

resource "aws_route53_record" "internal_qdrant" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "qdrant.internal.dev.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [module.compute.qdrant_private_ips["primary"]]
}

# =============================================================================
# Frontend (CloudFront)
# NOTE: 기존 dev.moyeobab.com A record 존재. CI/CD 검증 완료 후 import → apply.
#   terraform import aws_route53_record.frontend {ZONE_ID}_dev.moyeobab.com_A
# =============================================================================
resource "aws_route53_record" "frontend" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "dev.moyeobab.com"
  type    = "A"

  alias {
    name                   = module.frontend.cloudfront_domain
    zone_id                = module.frontend.cloudfront_hosted_zone_id
    evaluate_target_health = false
  }
}

# =============================================================================
# API DNS — ALB alias (V2 단일 라우팅)
# =============================================================================
resource "aws_route53_record" "api_v2" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.dev.moyeobab.com"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}
