variable "project"     { type = string }
variable "environment" { type = string }
variable "common_tags" { type = map(string) }


variable "oidc_provider_arn"      { type = string }
variable "oidc_subjects"          { type = list(string) }

variable "ecr_backend_arn"        { type = string }
variable "ecr_recommend_arn"      { type = string }

variable "frontend_s3_bucket_arn" { type = string }
variable "frontend_cloudfront_arn" { type = string }

variable "config_s3_bucket_arn"   { type = string }

variable "receipt_s3_bucket_arn" {
  type    = string
  default = ""
}

variable "enable_receipt_s3" {
  description = "Receipt S3 접근 권한 활성화"
  type        = bool
  default     = false
}

variable "region"                 { type = string }
variable "account_id"             { type = string }
