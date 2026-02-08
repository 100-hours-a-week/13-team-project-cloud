resource "aws_s3_bucket" "restaurant_images" {
  bucket = "moyeo-bab-restaurant-images"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "moyeo-bab-restaurant-images"
    Environment = "shared"
    Purpose     = "restaurant-crawling"
  }
}

resource "aws_s3_bucket_versioning" "restaurant_images" {
  bucket = aws_s3_bucket.restaurant_images.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "restaurant_images" {
  bucket = aws_s3_bucket.restaurant_images.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "restaurant_images" {
  bucket = aws_s3_bucket.restaurant_images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
