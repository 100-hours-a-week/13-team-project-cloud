# =============================================================================
# GitHub Actions OIDC Provider (계정당 1개)
# =============================================================================
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = merge(local.common_tags, {
    Name = "github-actions-oidc"
  })
}

# =============================================================================
# GitHub Actions IAM Role (AI, BE 레포 공용)
# =============================================================================
resource "aws_iam_role" "github_actions" {
  name = "${local.project}-github-actions"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = local.oidc_subjects
        }
      }
    }]
  })

  tags = merge(local.common_tags, {
    Name = "${local.project}-github-actions"
  })
}

# =============================================================================
# ECR Push 권한
# =============================================================================
resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "${local.project}-github-actions-ecr"
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
          aws_ecr_repository.backend.arn,
          aws_ecr_repository.recommend.arn,
        ]
      }
    ]
  })
}

# =============================================================================
# SSM Send Command 권한
# =============================================================================
resource "aws_iam_role_policy" "github_actions_ssm" {
  name = "${local.project}-github-actions-ssm"
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
          "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/*",
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
