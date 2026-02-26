# =============================================================================
# GitHub Actions IAM Role
# =============================================================================
resource "aws_iam_role" "github_actions" {
  name = "${var.project}-${var.environment}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = var.oidc_subjects
        }
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-github-actions"
  })
}

# =============================================================================
# ECR Push/Pull 권한
# =============================================================================
resource "aws_iam_role_policy" "ecr" {
  name = "${var.project}-${var.environment}-github-actions-ecr"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRGetToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
        ]
        Resource = [
          var.ecr_backend_arn,
          var.ecr_recommend_arn,
        ]
      }
    ]
  })
}

# =============================================================================
# SSM Send Command 권한 (배포 트리거)
# =============================================================================
resource "aws_iam_role_policy" "ssm" {
  name = "${var.project}-${var.environment}-github-actions-ssm"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMSendCommand"
        Effect = "Allow"
        Action = "ssm:SendCommand"
        Resource = [
          "arn:aws:ssm:${var.region}::document/AWS-RunShellScript",
          "arn:aws:ec2:${var.region}:${var.account_id}:instance/*",
        ]
      },
      {
        Sid    = "SSMCommandStatus"
        Effect = "Allow"
        Action = [
          "ssm:ListCommandInvocations",
          "ssm:GetCommandInvocation",
        ]
        Resource = "*"
      }
    ]
  })
}

# =============================================================================
# Frontend S3 + CloudFront 배포 권한
# =============================================================================
resource "aws_iam_role_policy" "frontend" {
  name = "${var.project}-${var.environment}-github-actions-frontend"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3SyncDeploy"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          var.frontend_s3_bucket_arn,
          "${var.frontend_s3_bucket_arn}/*",
        ]
      },
      {
        Sid      = "CloudFrontInvalidation"
        Effect   = "Allow"
        Action   = [
          "cloudfront:CreateInvalidation",
          "cloudfront:GetInvalidation"
        ]
        Resource = var.frontend_cloudfront_arn
      }
    ]
  })
}

# =============================================================================
# Config S3 업로드 권한 (docker-compose, promtail 등)
# =============================================================================
resource "aws_iam_role_policy" "config_s3" {
  name = "${var.project}-${var.environment}-github-actions-config-s3"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "S3ConfigWrite"
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:ListBucket",
      ]
      Resource = [
        var.config_s3_bucket_arn,
        "${var.config_s3_bucket_arn}/*",
      ]
    }]
  })
}

# =============================================================================
# Receipt S3 읽기/쓰기 권한 (영수증 이미지)
# =============================================================================
resource "aws_iam_role_policy" "receipt_s3" {
  count = var.enable_receipt_s3 ? 1 : 0

  name = "${var.project}-${var.environment}-github-actions-receipt-s3"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "S3ReceiptReadWrite"
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket",
      ]
      Resource = [
        var.receipt_s3_bucket_arn,
        "${var.receipt_s3_bucket_arn}/*",
      ]
    }]
  })
}
