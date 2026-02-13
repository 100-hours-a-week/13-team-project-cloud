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
resource "aws_route53_record" "internal_api" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "api.internal.dev.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.api.private_ip]
}

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

resource "aws_route53_record" "internal_loki" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "loki.internal.dev.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [var.v1_loki_ip]
}

# =============================================================================
# Weighted Records (Canary 전환용)
# 초기: v1 100% / v2 0%
# =============================================================================
# NOTE: 기존 simple A record (api.dev.moyeobab.com) 삭제 후 활성화할 것.
#       simple → weighted 전환은 기존 레코드 삭제가 선행되어야 함.
#       트래픽 적은 시간에 수동 전환 후 주석 해제.
#
# resource "aws_route53_record" "api_v2" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = "api.dev.moyeobab.com"
#   type    = "A"
#
#   alias {
#     name                   = aws_lb.main.dns_name
#     zone_id                = aws_lb.main.zone_id
#     evaluate_target_health = true
#   }
#
#   set_identifier = "v2"
#
#   weighted_routing_policy {
#     weight = 0
#   }
# }

# NOTE: v1 weighted record는 기존 A 레코드를 weighted로 변환해야 함.
# 기존 simple A record 삭제 후 weighted A record로 재생성 필요.
# 트래픽 적은 시간에 작업할 것.
#
# resource "aws_route53_record" "api_v1" {
#   zone_id = data.aws_route53_zone.main.zone_id
#   name    = "api.dev.moyeobab.com"
#   type    = "A"
#   ttl     = 60
#   records = ["<v1-api-public-ip>"]
#
#   set_identifier = "v1"
#   weighted_routing_policy {
#     weight = 100
#   }
# }
