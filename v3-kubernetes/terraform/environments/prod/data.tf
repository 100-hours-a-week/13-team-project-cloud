# =============================================================================
# 기존 v2-prod 리소스 참조 (data source — v3에서 관리하지 않음)
# =============================================================================

data "aws_caller_identity" "current" {}

# v2에서 생성한 Prod VPC
data "aws_vpc" "existing" {
  tags = {
    Name = "moyeobab-prod-v2"
  }
}

# App tier 서브넷 (멀티 AZ — CP, Worker 배치)
data "aws_subnets" "app" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  tags = {
    Tier = "app"
  }
}

# 첫 번째 App 서브넷 (CP 고정 IP 배치용)
data "aws_subnet" "app_primary" {
  id = sort(data.aws_subnets.app.ids)[0]
}

# Public 서브넷 (NLB 배치용)
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }

  tags = {
    Tier = "public"
  }
}

# Data tier Security Group (K8s 노드 인바운드 규칙 추가 대상)
data "aws_security_group" "data" {
  vpc_id = data.aws_vpc.existing.id

  tags = {
    Tier = "data"
  }
}

# ACM 인증서 (dev/prod 공용)
data "aws_acm_certificate" "main" {
  domain   = "moyeobab.com"
  statuses = ["ISSUED"]
}
