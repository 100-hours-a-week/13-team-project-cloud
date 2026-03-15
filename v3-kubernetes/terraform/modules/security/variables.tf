variable "project"     { type = string }
variable "environment" { type = string }
variable "app_version" { type = string }
variable "common_tags" { type = map(string) }
variable "vpc_id"      { type = string }

variable "data_sg_id" {
  description = "기존 v2 Data tier SG ID — K8s 노드에서 DB 접근 허용 규칙 추가"
  type        = string
}

variable "admin_cidr_blocks" {
  description = "K8s API Server(6443) 접근 허용 CIDR 목록 (관리자/Bastion)"
  type        = list(string)
  default     = []
}
