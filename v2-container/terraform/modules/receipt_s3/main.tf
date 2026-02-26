# =============================================================================
# S3 Bucket (영수증 이미지 저장)
# =============================================================================
resource "aws_s3_bucket" "receipt_images" {
  bucket = "${var.project}-${var.environment}-receipt-images"

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-receipt-images"
  })
}

resource "aws_s3_bucket_versioning" "receipt_images" {
  bucket = aws_s3_bucket.receipt_images.id
  versioning_configuration {
    status = "Enabled"
  }
}

# =============================================================================
# IAM Policy — EC2 -> Receipt S3 읽기/쓰기 권한
# =============================================================================
resource "aws_iam_role_policy" "ec2_receipt_s3" {
  name = "${var.project}-${var.environment}-ec2-receipt-s3"
  role = var.ec2_role_id

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
        aws_s3_bucket.receipt_images.arn,
        "${aws_s3_bucket.receipt_images.arn}/*",
      ]
    }]
  })
}
