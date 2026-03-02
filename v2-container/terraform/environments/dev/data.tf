data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

data "aws_route53_zone" "main" {
  name = "moyeobab.com"
}

data "aws_acm_certificate" "alb" {
  domain   = "moyeobab.com"
  statuses = ["ISSUED"]
}

data "aws_acm_certificate" "cloudfront" {
  provider = aws.virginia
  domain   = "moyeobab.com"
  statuses = ["ISSUED"]
}

# Recommend ASG 인스턴스 IP 조회 (DNS 자동화)
# NOTE: ASG 생성 후 인스턴스 기동 완료 전까지는 비어있을 수 있음 — 두 번째 apply에서 DNS 반영
data "aws_instances" "recommend" {
  filter {
    name   = "tag:Service"
    values = ["recommend"]
  }
  filter {
    name   = "tag:Environment"
    values = ["dev"]
  }
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [module.asg_recommend]
}
