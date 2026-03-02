output "bucket_arn" {
  value = aws_s3_bucket.receipt_images.arn
}

output "bucket_name" {
  value = aws_s3_bucket.receipt_images.bucket
}
