variable "project"     { type = string }
variable "environment" { type = string }
variable "app_version" { type = string }
variable "common_tags" { type = map(string) }

variable "vpc_id"            { type = string }
variable "public_subnet_ids" { type = list(string) }

variable "http_node_port" {
  type    = number
  default = 30080
}

variable "https_node_port" {
  type    = number
  default = 30443
}
