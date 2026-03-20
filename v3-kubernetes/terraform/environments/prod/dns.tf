# =============================================================================
# Private Hosted Zone — 기존 PHZ 참조
# =============================================================================
data "aws_route53_zone" "internal" {
  name         = "internal.moyeobab.com"
  private_zone = true
  vpc_id       = data.aws_vpc.existing.id
}

# =============================================================================
# 기존 v2 Data Layer EC2 참조 (IP 조회용)
# =============================================================================
data "aws_instance" "postgresql_primary" {
  filter {
    name   = "tag:Service"
    values = ["postgresql"]
  }
  filter {
    name   = "tag:Name"
    values = ["*-primary"]
  }
  filter {
    name   = "tag:Environment"
    values = [local.environment]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

data "aws_instance" "redis_primary" {
  filter {
    name   = "tag:Service"
    values = ["redis"]
  }
  filter {
    name   = "tag:Name"
    values = ["*-primary"]
  }
  filter {
    name   = "tag:Environment"
    values = [local.environment]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

data "aws_instance" "qdrant" {
  filter {
    name   = "tag:Service"
    values = ["qdrant"]
  }
  filter {
    name   = "tag:Environment"
    values = [local.environment]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# =============================================================================
# A 레코드 — 데이터 레이어 전체
# =============================================================================

# --- 신규 (v3 data-services 모듈 출력) ---
resource "aws_route53_record" "mongodb" {
  zone_id = data.aws_route53_zone.internal.zone_id
  name    = "mongo.internal.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [module.data_services.mongodb_private_ip]
}

resource "aws_route53_record" "rabbitmq" {
  zone_id = data.aws_route53_zone.internal.zone_id
  name    = "rabbitmq.internal.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [module.data_services.rabbitmq_private_ip]
}

# --- 기존 v2 인프라 ---
resource "aws_route53_record" "postgresql" {
  zone_id = data.aws_route53_zone.internal.zone_id
  name    = "postgresql.internal.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [data.aws_instance.postgresql_primary.private_ip]
}

resource "aws_route53_record" "redis" {
  zone_id = data.aws_route53_zone.internal.zone_id
  name    = "redis.internal.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [data.aws_instance.redis_primary.private_ip]
}

resource "aws_route53_record" "qdrant" {
  zone_id = data.aws_route53_zone.internal.zone_id
  name    = "qdrant.internal.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [data.aws_instance.qdrant.private_ip]
}
