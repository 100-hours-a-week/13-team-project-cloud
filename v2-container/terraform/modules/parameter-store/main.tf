# =============================================================================
# SSM Parameter Store — Spring Boot 환경변수
# 값은 AWS Console에서 관리, Terraform은 리소스 존재만 관리
# =============================================================================
resource "aws_ssm_parameter" "spring" {
  for_each = var.ssm_parameters

  name        = "${var.ssm_prefix}/${each.key}"
  type        = each.value.type
  description = each.value.description
  value       = "managed-by-console"

  lifecycle {
    ignore_changes = [value, key_id]
  }

  tags = var.common_tags
}

# =============================================================================
# SSM Parameter Store — Recommend (FastAPI) 환경변수
# =============================================================================
resource "aws_ssm_parameter" "recommend" {
  for_each = var.ssm_recommend_parameters

  name        = "${var.ssm_recommend_prefix}/${each.key}"
  type        = each.value.type
  description = each.value.description
  value       = "managed-by-console"

  lifecycle {
    ignore_changes = [value, key_id]
  }

  tags = var.common_tags
}

# =============================================================================
# IAM Policy — EC2 → Parameter Store 읽기 권한
# =============================================================================
resource "aws_iam_role_policy" "ec2_parameter_store" {
  name = "${var.project}-v2-${var.environment}-ec2-parameter-store"
  role = var.ec2_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMGetParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${var.region}:${var.account_id}:parameter/${var.project}/spring/${var.environment}",
          "arn:aws:ssm:${var.region}:${var.account_id}:parameter/${var.project}/spring/${var.environment}/*",
          "arn:aws:ssm:${var.region}:${var.account_id}:parameter/${var.project}/recommend/${var.environment}",
          "arn:aws:ssm:${var.region}:${var.account_id}:parameter/${var.project}/recommend/${var.environment}/*",
        ]
      },
      {
        Sid    = "KMSDecryptForSecureString"
        Effect = "Allow"
        Action = ["kms:Decrypt"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${var.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}
