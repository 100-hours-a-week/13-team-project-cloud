variable "project"             { type = string }
variable "environment"         { type = string }
variable "common_tags"         { type = map(string) }
variable "region"              { type = string }
variable "acm_certificate_arn" { type = string }
variable "domain_alias"        { type = string }
variable "price_class"         { type = string }
