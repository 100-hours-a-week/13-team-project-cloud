# =============================================================================
# S3 Bucket (배포 설정 파일 — docker-compose, promtail 등)
# =============================================================================
resource "aws_s3_bucket" "config" {
  bucket = "${var.project}-${var.environment}-config"

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-config"
  })
}

resource "aws_s3_bucket_versioning" "config" {
  bucket = aws_s3_bucket.config.id
  versioning_configuration {
    status = "Enabled"
  }
}

# =============================================================================
# IAM Policy — EC2 → Config S3 읽기 권한
# =============================================================================
resource "aws_iam_role_policy" "ec2_config_s3" {
  name = "${var.project}-v2-${var.environment}-ec2-config-s3"
  role = var.ec2_role_id

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
