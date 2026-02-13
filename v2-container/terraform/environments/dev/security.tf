# =============================================================================
# ALB Security Group
# =============================================================================
resource "aws_security_group" "alb" {
  name        = "${local.project}-${local.environment}-alb-sg"
  description = "moyeobab-dev-backend-sg" # 기존 SG description 유지 (ForceNew 방지)
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-alb-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# =============================================================================
# App Tier Security Group (API, Recommend)
# =============================================================================
resource "aws_security_group" "app" {
  # NOTE: v1 moyeoBab-dev-app-sg와 이름 충돌 (AWS SG name 대소문자 무시)
  #       v1 정리 후 moyeobab-dev-app-sg로 변경 예정
  name        = "${local.project}-${local.environment}-app-v2-sg"
  description = "App tier security group (API, Recommend)"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-app-v2-sg"
    Tier = "app"
  })
}

# ALB → API (8080)
resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

# API → Recommend 내부 통신 (8000)
resource "aws_vpc_security_group_ingress_rule" "app_internal" {
  security_group_id            = aws_security_group.app.id
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# =============================================================================
# App Monitoring Security Group (v1 Prometheus scrape 허용)
# =============================================================================
resource "aws_security_group" "app_monitoring" {
  name        = "${local.project}-${local.environment}-app-monitoring-sg"
  description = "App monitoring (node_exporter, actuator, AI metrics)"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-app-monitoring-sg"
  })
}

# node_exporter (9100) from v1 monitoring
resource "aws_vpc_security_group_ingress_rule" "app_mon_node_exporter" {
  security_group_id            = aws_security_group.app_monitoring.id
  from_port                    = 9100
  to_port                      = 9100
  ip_protocol                  = "tcp"
  referenced_security_group_id = local.v1_monitoring_sg_id
}

# Spring Actuator (8080) from v1 monitoring
resource "aws_vpc_security_group_ingress_rule" "app_mon_actuator" {
  security_group_id            = aws_security_group.app_monitoring.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = local.v1_monitoring_sg_id
}

# AI metrics (8000) from v1 monitoring
resource "aws_vpc_security_group_ingress_rule" "app_mon_ai_metrics" {
  security_group_id            = aws_security_group.app_monitoring.id
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
  referenced_security_group_id = local.v1_monitoring_sg_id
}

resource "aws_vpc_security_group_egress_rule" "app_mon_all" {
  security_group_id = aws_security_group.app_monitoring.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# =============================================================================
# Data Tier Security Group (PostgreSQL, Redis)
# =============================================================================
resource "aws_security_group" "data" {
  name        = "${local.project}-${local.environment}-data-sg"
  description = "Data tier security group (PostgreSQL, Redis)"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-data-sg"
    Tier = "data"
  })
}

# PostgreSQL (5432) from App tier
resource "aws_vpc_security_group_ingress_rule" "data_postgresql" {
  security_group_id            = aws_security_group.data.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

# Redis (6379) from App tier
resource "aws_vpc_security_group_ingress_rule" "data_redis" {
  security_group_id            = aws_security_group.data.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "data_all" {
  security_group_id = aws_security_group.data.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# =============================================================================
# Data Monitoring Security Group (v1 Prometheus scrape 허용)
# =============================================================================
resource "aws_security_group" "data_monitoring" {
  name        = "${local.project}-${local.environment}-data-monitoring-sg"
  description = "Data monitoring (node_exporter, postgres_exporter, redis_exporter)"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-data-monitoring-sg"
  })
}

# node_exporter (9100)
resource "aws_vpc_security_group_ingress_rule" "data_mon_node_exporter" {
  security_group_id            = aws_security_group.data_monitoring.id
  from_port                    = 9100
  to_port                      = 9100
  ip_protocol                  = "tcp"
  referenced_security_group_id = local.v1_monitoring_sg_id
}

# postgres_exporter (9187)
resource "aws_vpc_security_group_ingress_rule" "data_mon_postgres" {
  security_group_id            = aws_security_group.data_monitoring.id
  from_port                    = 9187
  to_port                      = 9187
  ip_protocol                  = "tcp"
  referenced_security_group_id = local.v1_monitoring_sg_id
}

# redis_exporter (9121)
resource "aws_vpc_security_group_ingress_rule" "data_mon_redis" {
  security_group_id            = aws_security_group.data_monitoring.id
  from_port                    = 9121
  to_port                      = 9121
  ip_protocol                  = "tcp"
  referenced_security_group_id = local.v1_monitoring_sg_id
}

resource "aws_vpc_security_group_egress_rule" "data_mon_all" {
  security_group_id = aws_security_group.data_monitoring.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# =============================================================================
# v1 Monitoring SG — v2에서 Loki 접근 허용
# =============================================================================

# Loki (3100) from v2 App tier
resource "aws_vpc_security_group_ingress_rule" "v1_mon_loki_from_v2_app" {
  security_group_id            = local.v1_monitoring_sg_id
  from_port                    = 3100
  to_port                      = 3100
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
  description                  = "Loki from v2 app tier"
}

# Loki (3100) from v2 Data tier
resource "aws_vpc_security_group_ingress_rule" "v1_mon_loki_from_v2_data" {
  security_group_id            = local.v1_monitoring_sg_id
  from_port                    = 3100
  to_port                      = 3100
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.data.id
  description                  = "Loki from v2 data tier"
}
