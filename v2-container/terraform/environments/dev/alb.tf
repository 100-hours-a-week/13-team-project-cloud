# =============================================================================
# Application Load Balancer
# =============================================================================
resource "aws_lb" "main" {
  # NOTE: name은 ForceNew — 기존 AWS 리소스명 그대로 유지 (대소문자 주의)
  name               = "moyeoBab-dev-ALB-v2"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-alb-v2"
  })
}

# =============================================================================
# Target Group — API (Spring Boot)
# =============================================================================
resource "aws_lb_target_group" "api" {
  # NOTE: name은 ForceNew — 기존 AWS 리소스명 유지 (WAS→api 변경은 재생성 필요)
  name     = "moyeoBab-dev-WAS-v2"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

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
    Name = "${local.project}-${local.environment}-api-tg-v2"
  })
}

resource "aws_lb_target_group_attachment" "api" {
  target_group_arn = aws_lb_target_group.api.arn
  target_id        = aws_instance.api.id
  port             = 8080
}

# =============================================================================
# Listeners
# =============================================================================

# HTTP → HTTPS redirect
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS → Forward to API
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = data.aws_acm_certificate.alb.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# =============================================================================
# Path Blocking (prod에서 활성화, dev에서는 비활성)
# =============================================================================
resource "aws_lb_listener_rule" "block_actuator" {
  count        = var.enable_path_blocking ? 1 : 0
  listener_arn = aws_lb_listener.https.arn
  priority     = 1

  condition {
    path_pattern {
      values = ["/actuator/*"]
    }
  }

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = "{\"error\":\"Forbidden\"}"
      status_code  = "403"
    }
  }
}

resource "aws_lb_listener_rule" "block_swagger" {
  count        = var.enable_path_blocking ? 1 : 0
  listener_arn = aws_lb_listener.https.arn
  priority     = 2

  condition {
    path_pattern {
      values = ["/swagger-ui/*", "/v3/api-docs/*"]
    }
  }

  action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = "{\"error\":\"Forbidden\"}"
      status_code  = "403"
    }
  }
}
