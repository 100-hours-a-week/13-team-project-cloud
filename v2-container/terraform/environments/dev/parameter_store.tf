# =============================================================================
# SSM Parameter Store — Spring Boot 환경변수
# 값은 AWS Console에서 관리, Terraform은 리소스 존재만 관리
# =============================================================================

resource "aws_ssm_parameter" "spring" {
  for_each = local.ssm_parameters

  name        = "${local.ssm_prefix}/${each.key}"
  type        = each.value.type
  description = each.value.description
  value       = "managed-by-console"

  lifecycle {
    ignore_changes = [value, key_id]
  }

  tags = local.common_tags
}

# =============================================================================
# SSM Parameter Store — Recommend (FastAPI) 환경변수
# =============================================================================
resource "aws_ssm_parameter" "recommend" {
  for_each = local.ssm_recommend_parameters

  name        = "${local.ssm_recommend_prefix}/${each.key}"
  type        = each.value.type
  description = each.value.description
  value       = "managed-by-console"

  lifecycle {
    ignore_changes = [value, key_id]
  }

  tags = local.common_tags
}

# =============================================================================
# IAM Policy — EC2 → Parameter Store 읽기 권한
# =============================================================================
data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "v2_ec2_parameter_store" {
  name = "${local.project}-v2-ec2-parameter-store"
  role = aws_iam_role.v2_ec2.id

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
          "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${local.project}/spring/${local.environment}",
          "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${local.project}/spring/${local.environment}/*",
          "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${local.project}/recommend/${local.environment}",
          "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${local.project}/recommend/${local.environment}/*",
        ]
      },
      {
        Sid    = "KMSDecryptForSecureString"
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
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
