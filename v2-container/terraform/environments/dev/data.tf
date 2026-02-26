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
