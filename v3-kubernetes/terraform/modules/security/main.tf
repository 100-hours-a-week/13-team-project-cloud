# =============================================================================
# K8s Node SG — 노드 간 전체 통신 허용
# =============================================================================
resource "aws_security_group" "k8s_node" {
  name        = "${var.project}-${var.environment}-${var.app_version}-k8s-node-sg"
  description = "K8s node-to-node (kubelet, flannel VXLAN, CoreDNS, Pod traffic)"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-k8s-node-sg"
    Tier = "k8s"
  })
}

resource "aws_vpc_security_group_ingress_rule" "k8s_node_self" {
  security_group_id            = aws_security_group.k8s_node.id
  referenced_security_group_id = aws_security_group.k8s_node.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "k8s_node_all" {
  security_group_id = aws_security_group.k8s_node.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# =============================================================================
# K8s Control Plane SG — API Server 외부 접근
# =============================================================================
resource "aws_security_group" "k8s_cp" {
  name        = "${var.project}-${var.environment}-${var.app_version}-k8s-cp-sg"
  description = "K8s API Server external access (6443)"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-k8s-cp-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "k8s_api" {
  count = length(var.admin_cidr_blocks)

  security_group_id = aws_security_group.k8s_cp.id
  from_port         = 6443
  to_port           = 6443
  ip_protocol       = "tcp"
  cidr_ipv4         = var.admin_cidr_blocks[count.index]
}

resource "aws_vpc_security_group_egress_rule" "k8s_cp_all" {
  security_group_id = aws_security_group.k8s_cp.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# =============================================================================
# NLB 트래픽 허용 — Public NLB → K8s 노드 (Traefik NodePort)
# NLB는 SG를 거치지 않으므로 타겟 노드 SG에서 직접 허용
# =============================================================================
resource "aws_vpc_security_group_ingress_rule" "k8s_nlb_http" {
  security_group_id = aws_security_group.k8s_node.id
  from_port         = 30080
  to_port           = 30080
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "k8s_nlb_https" {
  security_group_id = aws_security_group.k8s_node.id
  from_port         = 30443
  to_port           = 30443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# =============================================================================
# 기존 Data SG에 K8s 노드 인바운드 추가
# Pod → EC2 Data Layer 통신은 Node IP로 SNAT되므로 k8s-node-sg 허용
# =============================================================================
resource "aws_vpc_security_group_ingress_rule" "data_postgresql_from_k8s" {
  security_group_id            = var.data_sg_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s_node.id
}

resource "aws_vpc_security_group_ingress_rule" "data_redis_from_k8s" {
  security_group_id            = var.data_sg_id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s_node.id
}

resource "aws_vpc_security_group_ingress_rule" "data_redis_sentinel_from_k8s" {
  security_group_id            = var.data_sg_id
  from_port                    = 26379
  to_port                      = 26379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s_node.id
}

resource "aws_vpc_security_group_ingress_rule" "data_qdrant_from_k8s" {
  security_group_id            = var.data_sg_id
  from_port                    = 6333
  to_port                      = 6333
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.k8s_node.id
}
