# v1 monitoring SG 참조 (v2 인스턴스 메트릭 scrape 허용)
data "terraform_remote_state" "v1_monitoring" {
  backend = "s3"
  config = {
    bucket = "moyeo-bab-tfstate-dev"
    key    = "environments/dev-monitoring/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

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

# v1 monitoring SG ID
locals {
  v1_monitoring_sg_id = data.terraform_remote_state.v1_monitoring.outputs.monitoring_security_group_id
}
