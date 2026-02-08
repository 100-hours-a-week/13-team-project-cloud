resource "aws_security_group" "monitoring" {
  name        = "${var.name}-sg"
  description = "Security group for monitoring server (Loki + Grafana)"
  vpc_id      = var.vpc_id

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidrs
  }

  # Loki (app server -> monitoring)
  ingress {
    description = "Loki"
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = var.loki_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    { Name = "${var.name}-sg" },
    var.tags
  )
}

resource "aws_security_group_rule" "grafana_from_app" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  description              = "Grafana from app server"
  security_group_id        = aws_security_group.monitoring.id
  source_security_group_id = var.app_security_group_id
}
