variable "project"               { type = string }
variable "environment"           { type = string }
variable "app_version"           { type = string }
variable "common_tags"           { type = map(string) }
variable "service_tags"          { type = map(map(string)) }
variable "ec2_ami_id"            { type = string }
variable "ec2_instance_type"     { type = string }
variable "ec2_key_name"          { type = string }
variable "private_app_subnet_id"  { type = string }
variable "private_data_subnet_id" { type = string }
variable "app_sg_id"             { type = string }
variable "data_sg_id"            { type = string }

variable "app_monitoring_sg_id" {
  description = "App tier monitoring SG ID (빈 문자열이면 미적용)"
  type        = string
  default     = ""
}

variable "data_monitoring_sg_id" {
  description = "Data tier monitoring SG ID (빈 문자열이면 미적용)"
  type        = string
  default     = ""
}

variable "enable_backend_2" {
  description = "두 번째 백엔드 인스턴스 생성 여부"
  type        = bool
  default     = true
}

variable "backend_private_ip" {
  description = "Backend 고정 Private IP (null이면 자동 할당)"
  type        = string
  default     = null
}

variable "recommend_private_ip" {
  description = "Recommend 고정 Private IP (null이면 자동 할당)"
  type        = string
  default     = null
}

variable "postgresql_private_ip" {
  description = "PostgreSQL 고정 Private IP (null이면 자동 할당)"
  type        = string
  default     = null
}

variable "redis_private_ip" {
  description = "Redis 고정 Private IP (null이면 자동 할당)"
  type        = string
  default     = null
}

variable "postgresql_extra_sg_ids" {
  description = "PostgreSQL에 추가할 Security Group ID 목록"
  type        = list(string)
  default     = []
}
