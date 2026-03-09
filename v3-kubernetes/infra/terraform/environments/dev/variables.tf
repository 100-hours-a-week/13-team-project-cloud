variable "region" {
  type    = string
  default = "ap-northeast-2"
}

variable "availability_zones" {
  type = list(string)
}

variable "k8s_subnet_cidrs" {
  description = "K8s 노드 서브넷 CIDR 목록 (AZ별)"
  type        = list(string)
}

variable "ec2_ami_id" {
  description = "K8s 노드용 AMI ID"
  type        = string
}

variable "admin_cidr_blocks" {
  description = "K8s API Server 접근 허용 CIDR"
  type        = list(string)
  default     = []
}
