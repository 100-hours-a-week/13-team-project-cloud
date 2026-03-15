variable "project"     { type = string }
variable "environment" { type = string }
variable "app_version" { type = string }
variable "common_tags" { type = map(string) }

variable "ec2_ami_id"            { type = string }
variable "instance_type"         { type = string }
variable "instance_profile_name" { type = string }

variable "subnet_id"      { type = string }
variable "k8s_node_sg_id" { type = string }
variable "region"         { type = string }
variable "account_id"     { type = string }

variable "deploy_env" {
  description = "배포 환경 (dev|prod) — user_data SSM 경로에 사용"
  type        = string
}

variable "target_group_arns" {
  description = "NLB 타겟그룹 ARN 목록 (ASG 자동 등록)"
  type        = list(string)
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}

variable "volume_size" {
  type    = number
  default = 30
}
