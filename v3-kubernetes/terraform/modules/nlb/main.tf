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
# Target Group — Worker NodePort (HTTPS)
# =============================================================================
resource "aws_lb_target_group" "https" {
  name_prefix = "k8htps"
  port        = var.https_node_port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "TCP"
    port                = var.https_node_port
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-k8s-https-tg"
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
# Listener — 443 → HTTPS Target Group
# =============================================================================
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.k8s.arn
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}

