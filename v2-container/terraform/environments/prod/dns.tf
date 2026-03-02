# =============================================================================
# Private Hosted Zone (VPC 내부 서비스 디스커버리)
# =============================================================================
resource "aws_route53_zone" "internal" {
  name = "internal.moyeobab.com"

  vpc {
    vpc_id = module.network.vpc_id
  }

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-internal-zone"
  })
}

# Internal DNS — Backend는 ASG로 전환, ALB를 통해 접근
resource "aws_route53_record" "internal_api" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "api.internal.moyeobab.com"
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "internal_recommend" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "recommend.internal.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [module.compute.recommend_private_ip]
}

resource "aws_route53_record" "internal_postgresql" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "db.internal.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [module.compute.postgresql_private_ips["primary"]]
}

resource "aws_route53_record" "internal_redis" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "redis.internal.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [module.compute.redis_private_ips["primary"]]
}

resource "aws_route53_record" "internal_qdrant" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "qdrant.internal.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [module.compute.qdrant_private_ips["primary"]]
}

# =============================================================================
# Frontend (CloudFront)
# NOTE: 프론트엔드 S3 배포 완료 후 아래 주석 해제 + moyeobab.com 기존 A 레코드 삭제 후 apply
# =============================================================================
# resource "aws_route53_record" "frontend" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = "moyeobab.com"
#   type    = "A"
#
#   alias {
#     name                   = module.frontend.cloudfront_domain
#     zone_id                = module.frontend.cloudfront_hosted_zone_id
#     evaluate_target_health = false
#   }
# }

# =============================================================================
# API DNS — ALB alias (Canary는 ALB weighted TG로 제어)
# NOTE: 현재 api.moyeobab.com은 plain A record (v1 EC2 3.38.24.147)
#   apply 전 Route53 콘솔에서 기존 plain A 삭제 후 주석 해제
#   또는 v2 검증 완료 후 DNS 전환 시점에 주석 해제 + apply
# =============================================================================
# resource "aws_route53_record" "api" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = "api.moyeobab.com"
#   type    = "A"
#
#   alias {
#     name                   = aws_lb.main.dns_name
#     zone_id                = aws_lb.main.zone_id
#     evaluate_target_health = true
#   }
# }
