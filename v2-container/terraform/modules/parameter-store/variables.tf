variable "project"     { type = string }
variable "environment" { type = string }
variable "common_tags" { type = map(string) }
variable "region"      { type = string }
variable "account_id"  { type = string }
variable "ec2_role_id" { type = string }

variable "ssm_prefix"           { type = string }
variable "ssm_recommend_prefix" { type = string }

variable "ssm_parameters" {
  type = map(object({
    type        = string
    description = string
  }))
}

variable "ssm_recommend_parameters" {
  type = map(object({
    type        = string
    description = string
  }))
}
