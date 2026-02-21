# =============================================================================
# Private Hosted Zone (VPC 내부 서비스 디스커버리)
# =============================================================================
resource "aws_route53_zone" "internal" {
  name = "internal.dev.moyeobab.com"

  vpc {
    vpc_id = aws_vpc.main.id
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
  records = [aws_instance.recommend.private_ip]
}

resource "aws_route53_record" "internal_postgresql" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "db.internal.dev.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.postgresql.private_ip]
}

resource "aws_route53_record" "internal_redis" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "redis.internal.dev.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.redis.private_ip]
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
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
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
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
