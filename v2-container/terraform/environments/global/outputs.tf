output "oidc_provider_arn" {
  description = "GitHub Actions OIDC provider ARN (dev/prod에서 data source로 참조)"
  value       = aws_iam_openid_connect_provider.github.arn
}
