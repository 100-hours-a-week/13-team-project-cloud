variable "project"     { type = string }
variable "environment" { type = string }
variable "app_version" { type = string }
variable "common_tags" { type = map(string) }

variable "vpc_id"    { type = string }
variable "subnet_id" { type = string }

variable "data_sg_id" {
  description = "기존 v2 Data tier SG ID"
  type        = string
}

variable "ec2_ami_id" {
  description = "Ubuntu 24.04 ARM AMI"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM Instance Profile (SSM 접근용)"
  type        = string
}

variable "rabbitmq_instance_type" {
  description = "RabbitMQ 인스턴스 유형"
  type        = string
  default     = "t4g.small"
}

variable "mongodb_instance_type" {
  description = "MongoDB 인스턴스 유형"
  type        = string
  default     = "t4g.small"
}

variable "rabbitmq_volume_size" {
  type    = number
  default = 30
}

variable "mongodb_volume_size" {
  type    = number
  default = 30
}

variable "rabbitmq_user" {
  description = "RabbitMQ 관리자 사용자명"
  type        = string
  default     = "moyeobab"
}

variable "rabbitmq_password" {
  description = "RabbitMQ 관리자 비밀번호"
  type        = string
  sensitive   = true
}

variable "mongodb_admin_user" {
  description = "MongoDB 관리자 사용자명"
  type        = string
  default     = "moyeobab"
}

variable "mongodb_admin_password" {
  description = "MongoDB 관리자 비밀번호"
  type        = string
  sensitive   = true
}
