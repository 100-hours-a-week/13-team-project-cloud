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

# 기존 App tier 서브넷 (K8s 노드를 동일 서브넷에 배치)
data "aws_subnet" "app" {
  vpc_id = data.aws_vpc.existing.id

  tags = {
    Tier = "app"
  }
}

# 기존 Public 서브넷 (NLB 배치용)
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  tags = {
    Tier = "public"
  }
}

# 기존 Data tier Security Group (K8s 노드 인바운드 규칙 추가 대상)
data "aws_security_group" "data" {
  vpc_id = data.aws_vpc.existing.id

  tags = {
    Tier = "data"
  }
}
