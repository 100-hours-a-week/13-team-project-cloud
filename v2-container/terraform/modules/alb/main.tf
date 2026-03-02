resource "aws_lb" "main" {
  # NOTE: name은 ForceNew — 기존 AWS 리소스명 유지
  name               = "moyeoBab-${var.environment}-ALB-${var.app_version}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-alb"
  })
}

resource "aws_lb_target_group" "backend" {
  # NOTE: name은 ForceNew — 기존 AWS 리소스명 유지
  name     = "moyeoBab-${var.environment}-WAS-${var.app_version}"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

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

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-api-tg"
  })
}

resource "aws_lb_target_group_attachment" "backend_1" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = var.backend_1_id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "backend_2" {
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = var.backend_2_id
  port             = 8080
}

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

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.backend.arn
        weight = 100
      }
      stickiness {
        enabled  = false
        duration = 1
      }
    }
  }
}

resource "aws_lb_listener_rule" "block_actuator" {
  count        = var.enable_path_blocking ? 1 : 0
  listener_arn = aws_lb_listener.https.arn
  priority     = 2

  condition {
    path_pattern {
      values = ["/actuator", "/actuator/*"]
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
  priority     = 3

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
