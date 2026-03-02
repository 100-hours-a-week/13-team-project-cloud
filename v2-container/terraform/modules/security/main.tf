resource "aws_security_group" "alb" {
  name        = "${var.project}-${var.environment}-alb-sg"
  description = "moyeobab-dev-backend-sg"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-alb-sg"
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

resource "aws_security_group" "app" {
  name        = "${var.project}-${var.environment}-app-${var.app_version}-sg"
  description = "App tier security group (API, Recommend)"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-app-sg"
    Tier = "app"
  })
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

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

resource "aws_security_group" "app_monitoring" {
  name        = "${var.project}-${var.environment}-app-monitoring-sg"
  description = "App monitoring (node_exporter, actuator, AI metrics)"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-app-monitoring-sg"
  })
}

resource "aws_vpc_security_group_egress_rule" "app_mon_all" {
  security_group_id = aws_security_group.app_monitoring.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "data" {
  name        = "${var.project}-${var.environment}-data-sg"
  description = "Data tier security group (PostgreSQL, Redis)"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-data-sg"
    Tier = "data"
  })
}

resource "aws_vpc_security_group_ingress_rule" "data_postgresql" {
  security_group_id            = aws_security_group.data.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "data_redis" {
  security_group_id            = aws_security_group.data.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "data_qdrant" {
  security_group_id            = aws_security_group.data.id
  from_port                    = 6333
  to_port                      = 6333
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_egress_rule" "data_all" {
  security_group_id = aws_security_group.data.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "data_monitoring" {
  name        = "${var.project}-${var.environment}-data-monitoring-sg"
  description = "Data monitoring (node_exporter, postgres_exporter, redis_exporter)"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-data-monitoring-sg"
  })
}

resource "aws_vpc_security_group_egress_rule" "data_mon_all" {
  security_group_id = aws_security_group.data_monitoring.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
