output "cloudfront_domain"      { value = aws_cloudfront_distribution.frontend.domain_name }
output "cloudfront_hosted_zone_id" { value = aws_cloudfront_distribution.frontend.hosted_zone_id }
output "cloudfront_id"          { value = aws_cloudfront_distribution.frontend.id }
output "cloudfront_arn"         { value = aws_cloudfront_distribution.frontend.arn }
output "s3_bucket_name"         { value = aws_s3_bucket.frontend.bucket }
output "s3_bucket_arn"          { value = aws_s3_bucket.frontend.arn }
