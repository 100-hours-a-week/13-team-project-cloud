output "repository_urls" {
  description = "서비스별 ECR 레포지토리 URL"
  value       = { for k, v in aws_ecr_repository.repos : k => v.repository_url }
}

output "repository_arns" {
  description = "서비스별 ECR 레포지토리 ARN"
  value       = { for k, v in aws_ecr_repository.repos : k => v.arn }
}
