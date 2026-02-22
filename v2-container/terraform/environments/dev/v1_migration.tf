# =============================================================================
# V1 Legacy Migration & Integration
# -----------------------------------------------------------------------------
# 이 파일은 v1 -> v2 마이그레이션 과도기 동안 필요한 리소스와 설정을 담고 있습니다.
# v1 환경이 완전히 종료되면 이 파일 전체를 삭제하면 됩니다.
# =============================================================================

# -----------------------------------------------------------------------------
# 1. V1 Instances Lookup
# -----------------------------------------------------------------------------
data "aws_instance" "v1_backend" {
  filter {
    name   = "tag:Name"
    values = ["moyeoBab-dev-app-v1"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

data "aws_instance" "v1_loki" {
  filter {
    name   = "tag:Name"
    values = ["moyeoBab-dev-monitoring"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# -----------------------------------------------------------------------------
# 2. Local Values (V1 References)
# -----------------------------------------------------------------------------
locals {
  # Security Group ID for V1 Monitoring Server (for allowing scrape access)
  # v1 인스턴스가 여러 보안 그룹을 가질 수 있으므로 첫 번째 것을 사용하거나 특정 필터링 필요
  # 여기서는 v1_loki 인스턴스에 할당된 보안 그룹 중 하나를 사용
  v1_monitoring_sg_id = tolist(data.aws_instance.v1_loki.vpc_security_group_ids)[0]
}

# -----------------------------------------------------------------------------
# 3. Resources - Load Balancer (Canary)
# -----------------------------------------------------------------------------
resource "aws_lb_target_group" "backend_v1" {
  name        = "moyeoBab-dev-WAS-v1"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/api/ping"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-api-tg-v1"
  })
}

resource "aws_lb_target_group_attachment" "backend_v1" {
  target_group_arn = aws_lb_target_group.backend_v1.arn
  target_id        = data.aws_instance.v1_backend.private_ip
  port             = 8080
}

# -----------------------------------------------------------------------------
# 5. Resources - DNS (Monitoring)
# -----------------------------------------------------------------------------
resource "aws_route53_record" "internal_loki" {
  zone_id = aws_route53_zone.internal.zone_id
  name    = "loki.internal.dev.moyeobab.com"
  type    = "A"
  ttl     = 300
  records = [data.aws_instance.v1_loki.private_ip]
}
