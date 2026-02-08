resource "aws_security_group" "app" {
  name        = "${var.name}-sg"
  description = "Allow SSH/HTTP/HTTPS"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_cidrs
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.http_cidrs
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.http_cidrs
  }

  ingress {
    description = "WireGuard"
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = var.wireguard_cidrs
  }

  dynamic "ingress" {
    for_each = var.monitoring_security_group_id != "" ? [
      { desc = "Node Exporter", port = 9100 },
      { desc = "Nginx Exporter", port = 9113 },
      { desc = "Redis Exporter", port = 9121 },
      { desc = "Postgres Exporter", port = 9187 },
      { desc = "Spring Boot Actuator", port = 8080 },
      { desc = "FastAPI Metrics", port = 8000 },
    ] : []

    content {
      description     = ingress.value.desc
      from_port       = ingress.value.port
      to_port         = ingress.value.port
      protocol        = "tcp"
      security_groups = [var.monitoring_security_group_id]
    }
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
