# =============================================================================
# K8s Node Subnets — 기존 VPC에 추가
# =============================================================================
resource "aws_subnet" "k8s" {
  count = length(var.k8s_subnet_cidrs)

  vpc_id            = var.vpc_id
  cidr_block        = var.k8s_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-k8s-subnet-${count.index + 1}"
    Tier = "k8s"
  })
}

# =============================================================================
# Route Tables — AZ당 1개, 기존 NAT Gateway 참조
# =============================================================================
resource "aws_route_table" "k8s" {
  count  = length(var.k8s_subnet_cidrs)
  vpc_id = var.vpc_id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.nat_gateway_ids[count.index]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-k8s-private-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "k8s" {
  count          = length(aws_subnet.k8s)
  subnet_id      = aws_subnet.k8s[count.index].id
  route_table_id = aws_route_table.k8s[count.index].id
}
