variable "project"               { type = string }
variable "environment"           { type = string }
variable "app_version"           { type = string }
variable "common_tags"           { type = map(string) }
variable "service_tags" {
  type = map(map(string))
  default = {
    backend = {
      Tier        = "app"
      Service     = "backend"
      ServicePort = "8080"
      MetricsPath = "/actuator/prometheus"
    }
    recommend = {
      Tier        = "app"
      Service     = "recommend"
      ServicePort = "8000"
      MetricsPath = "/metrics"
    }
    postgresql = {
      Tier        = "data"
      Service     = "postgresql"
      ServicePort = "5432"
      MetricsPath = ""
    }
    redis = {
      Tier        = "data"
      Service     = "redis"
      ServicePort = "6379"
      MetricsPath = ""
    }
  }
}
variable "ec2_ami_id"            { type = string }
variable "ec2_instance_type" {
  type    = string
  default = "t4g.small"
}
variable "ec2_key_name" {
  type    = string
  default = "tasteCompass-key"
}
variable "private_app_subnet_id"  { type = string }
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

variable "enable_backend" {
  description = "백엔드 EC2 인스턴스 생성 여부 (ASG 사용 시 false)"
  type        = bool
  default     = true
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

variable "postgresql_instances" {
  description = "PostgreSQL 인스턴스 맵 (key = 인스턴스 이름, e.g. primary, standby)"
  type = map(object({
    subnet_id     = string
    private_ip    = optional(string)
    instance_type = optional(string)
    volume_size   = optional(number, 50)
  }))
}

variable "redis_instances" {
  description = "Redis 인스턴스 맵 (key = 인스턴스 이름, e.g. primary, replica)"
  type = map(object({
    subnet_id     = string
    private_ip    = optional(string)
    instance_type = optional(string)
    volume_size   = optional(number, 20)
  }))
}
