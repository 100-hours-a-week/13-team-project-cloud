# =============================================================================
# 기존 v2 리소스 참조 (data source — v3에서 관리하지 않음)
# =============================================================================

data "aws_caller_identity" "current" {}

# v2에서 생성한 VPC
data "aws_vpc" "existing" {
  tags = {
    Name = "moyeobab-dev-v2"
  }
}

# 기존 NAT Gateway (K8s 서브넷 라우팅에 재사용)
data "aws_nat_gateways" "existing" {
  vpc_id = data.aws_vpc.existing.id
}

data "aws_nat_gateway" "by_az" {
  count = length(var.availability_zones)

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  # NAT Gateway ID 목록에서 순서대로 참조
  id = tolist(data.aws_nat_gateways.existing.ids)[count.index]
}

# 기존 Data tier Security Group (K8s 노드 인바운드 규칙 추가 대상)
data "aws_security_group" "data" {
  vpc_id = data.aws_vpc.existing.id

  tags = {
    Tier = "data"
  }
}
