variable "region" {
  type    = string
  default = "ap-northeast-2"
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

variable "cp_instance_type" {
  description = "Control Plane 인스턴스 유형"
  type        = string
  default     = "t4g.large"
}

variable "wp_instance_type" {
  description = "Worker 인스턴스 유형"
  type        = string
  default     = "t4g.large"
}

variable "wp_asg_desired" {
  description = "Worker ASG desired capacity"
  type        = number
  default     = 2
}

variable "wp_asg_min" {
  description = "Worker ASG min size"
  type        = number
  default     = 2
}

variable "wp_asg_max" {
  description = "Worker ASG max size"
  type        = number
  default     = 4
}

# =============================================================================
# Data Services — MongoDB + RabbitMQ
# =============================================================================
variable "rabbitmq_instance_type" {
  type    = string
  default = "t4g.small"
}

variable "rabbitmq_user" {
  type    = string
  default = "moyeobab"
}

variable "rabbitmq_password" {
  type      = string
  sensitive = true
}

variable "mongodb_instance_type" {
  type    = string
  default = "t4g.small"
}

variable "mongodb_admin_user" {
  type    = string
  default = "moyeobab"
}

variable "mongodb_admin_password" {
  type      = string
  sensitive = true
}
