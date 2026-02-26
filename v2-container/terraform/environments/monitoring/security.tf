# =============================================================================
# Monitoring Security Group
# =============================================================================
resource "aws_security_group" "monitoring" {
  name        = "moyeobab-monitoring-v2-sg"
  description = "monitoring v2 server security group"
  vpc_id      = data.aws_vpc.dev.id

  tags = {
    Name      = "moyeobab-monitoring-v2-sg"
    Project   = var.project
    ManagedBy = "terraform"
  }
}

# =============================================================================
# Ingress Rules
# =============================================================================

# Grafana (3000) — Wireguard 등 제한된 접근
resource "aws_vpc_security_group_ingress_rule" "grafana" {
  for_each = toset(var.grafana_cidrs)

  security_group_id = aws_security_group.monitoring.id
  from_port         = 3000
  to_port           = 3000
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
  description       = "Wireguard to Grafana"
}

# Loki (3100) — dev app/data SG + prod VPC에서 로그 전송
resource "aws_vpc_security_group_ingress_rule" "loki_from_prod" {
  security_group_id = aws_security_group.monitoring.id
  from_port         = 3100
  to_port           = 3100
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.0.0.0/16"
  description       = "Loki from prod VPC"
}

resource "aws_vpc_security_group_ingress_rule" "loki_from_dev_app" {
  security_group_id            = aws_security_group.monitoring.id
  from_port                    = 3100
  to_port                      = 3100
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_security_group.dev_app.id
  description                  = "Loki from dev app tier"
}

resource "aws_vpc_security_group_ingress_rule" "loki_from_dev_data" {
  security_group_id            = aws_security_group.monitoring.id
  from_port                    = 3100
  to_port                      = 3100
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_security_group.dev_data.id
  description                  = "Loki from dev data tier"
}

# =============================================================================
# Egress Rules (Prometheus scraping + SSM + Loki)
# =============================================================================

# Spring Actuator (8080) — dev app + prod
resource "aws_vpc_security_group_egress_rule" "scrape_actuator_app" {
  security_group_id            = aws_security_group.monitoring.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_security_group.dev_app.id
  description                  = "Actuator scrape to dev app"
}

resource "aws_vpc_security_group_egress_rule" "scrape_actuator_prod" {
  security_group_id = aws_security_group.monitoring.id
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.0.0.0/16"
  description       = "Actuator scrape to prod"
}

# FastAPI metrics (8000) — dev app + prod
resource "aws_vpc_security_group_egress_rule" "scrape_fastapi_app" {
  security_group_id            = aws_security_group.monitoring.id
  from_port                    = 8000
  to_port                      = 8000
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_security_group.dev_app.id
  description                  = "FastAPI metrics to dev app"
}

resource "aws_vpc_security_group_egress_rule" "scrape_fastapi_prod" {
  security_group_id = aws_security_group.monitoring.id
  from_port         = 8000
  to_port           = 8000
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.0.0.0/16"
  description       = "FastAPI metrics to prod"
}

# Node Exporter (9100) — dev app/data + prod
resource "aws_vpc_security_group_egress_rule" "scrape_node_app" {
  security_group_id            = aws_security_group.monitoring.id
  from_port                    = 9100
  to_port                      = 9100
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_security_group.dev_app.id
  description                  = "Node exporter to dev app"
}

resource "aws_vpc_security_group_egress_rule" "scrape_node_data" {
  security_group_id            = aws_security_group.monitoring.id
  from_port                    = 9100
  to_port                      = 9100
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_security_group.dev_data.id
  description                  = "Node exporter to dev data"
}

resource "aws_vpc_security_group_egress_rule" "scrape_node_prod" {
  security_group_id = aws_security_group.monitoring.id
  from_port         = 9100
  to_port           = 9100
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.0.0.0/16"
  description       = "Node exporter to prod"
}

# PostgreSQL Exporter (9187) — dev data + prod
resource "aws_vpc_security_group_egress_rule" "scrape_pg_data" {
  security_group_id            = aws_security_group.monitoring.id
  from_port                    = 9187
  to_port                      = 9187
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_security_group.dev_data.id
  description                  = "PostgreSQL exporter to dev data"
}

resource "aws_vpc_security_group_egress_rule" "scrape_pg_prod" {
  security_group_id = aws_security_group.monitoring.id
  from_port         = 9187
  to_port           = 9187
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.0.0.0/16"
  description       = "PostgreSQL exporter to prod"
}

# Redis Exporter (9121) — dev data + prod
resource "aws_vpc_security_group_egress_rule" "scrape_redis_data" {
  security_group_id            = aws_security_group.monitoring.id
  from_port                    = 9121
  to_port                      = 9121
  ip_protocol                  = "tcp"
  referenced_security_group_id = data.aws_security_group.dev_data.id
  description                  = "Redis exporter to dev data"
}

resource "aws_vpc_security_group_egress_rule" "scrape_redis_prod" {
  security_group_id = aws_security_group.monitoring.id
  from_port         = 9121
  to_port           = 9121
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.0.0.0/16"
  description       = "Redis exporter to prod"
}

# Loki (3100) — outbound to prod
resource "aws_vpc_security_group_egress_rule" "loki_outbound" {
  security_group_id = aws_security_group.monitoring.id
  from_port         = 3100
  to_port           = 3100
  ip_protocol       = "tcp"
  cidr_ipv4         = "10.0.0.0/16"
  description       = "Loki outbound to prod"
}

# HTTPS (443) — SSM Agent
resource "aws_vpc_security_group_egress_rule" "https_ssm" {
  security_group_id = aws_security_group.monitoring.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
  description       = "SSM"
}
