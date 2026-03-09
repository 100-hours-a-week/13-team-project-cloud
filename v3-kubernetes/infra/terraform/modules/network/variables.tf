variable "project"            { type = string }
variable "environment"        { type = string }
variable "app_version"        { type = string }
variable "common_tags"        { type = map(string) }

variable "vpc_id"             { type = string }
variable "availability_zones" { type = list(string) }
variable "k8s_subnet_cidrs"   { type = list(string) }
variable "nat_gateway_ids"    { type = list(string) }
