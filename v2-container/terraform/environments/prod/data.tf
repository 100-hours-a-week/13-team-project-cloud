# ACM 인증서 (ALB HTTPS용, ap-northeast-2)
data "aws_acm_certificate" "alb" {
  domain      = "moyeobab.com"
  statuses    = ["ISSUED"]
  most_recent = true
}

# CloudFront ACM 인증서 (us-east-1 리전, aliased provider)
data "aws_acm_certificate" "cloudfront" {
  provider    = aws.virginia
  domain      = "moyeobab.com"
  statuses    = ["ISSUED"]
  most_recent = true
}

# Route53 Hosted Zone
data "aws_route53_zone" "main" {
  name = "moyeobab.com."
}

# AWS Account ID
data "aws_caller_identity" "current" {}

# GitHub Actions OIDC Provider (계정당 1개 — dev에서 생성)
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}
