# =============================================================================
# S3 Bucket (배포 설정 파일 — docker-compose, promtail 등)
# =============================================================================
resource "aws_s3_bucket" "config" {
  bucket = "${local.project}-${local.environment}-config"

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-config"
  })
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id
  versioning_configuration {
    status = "Enabled"
  }
}

# EC2 인스턴스가 config 파일을 다운로드할 수 있도록
resource "aws_iam_role_policy" "v2_ec2_config_s3" {
  name = "${local.project}-v2-ec2-config-s3"
  role = module.compute.ec2_role_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "S3ConfigRead"
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket",
      ]
      Resource = [
        aws_s3_bucket.config.arn,
        "${aws_s3_bucket.config.arn}/*",
      ]
    }]
  })
}

# GitHub Actions가 config 파일을 업로드할 수 있도록
resource "aws_iam_role_policy" "github_actions_config_s3" {
  name = "${local.project}-github-actions-config-s3"
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
        aws_s3_bucket.config.arn,
        "${aws_s3_bucket.config.arn}/*",
      ]
    }]
  })
}
