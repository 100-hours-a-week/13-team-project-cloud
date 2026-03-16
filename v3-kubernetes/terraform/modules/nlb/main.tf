# =============================================================================
# NLB — Public 서브넷에 배치, Traefik NodePort로 라우팅
# =============================================================================
resource "aws_lb" "k8s" {
  name               = "${var.project}-${var.environment}-${var.app_version}-k8s-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-k8s-nlb"
  })
}

# =============================================================================
# Target Group — Worker NodePort (HTTP)
# =============================================================================
resource "aws_lb_target_group" "http" {
  name_prefix = "k8http"
  port        = var.http_node_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    port                = var.http_node_port
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-k8s-http-tg"
  })
}


# =============================================================================
# Listener — 80 → HTTP Target Group
# =============================================================================
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.k8s.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

# =============================================================================
# Listener — 443 (TLS) → HTTP Target Group (ACM에서 TLS 종료)
# =============================================================================
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.k8s.arn
  port              = 443
  protocol          = "TLS"
  certificate_arn   = var.acm_certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

