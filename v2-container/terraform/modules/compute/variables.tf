variable "project"               { type = string }
variable "environment"           { type = string }
variable "app_version"           { type = string }
variable "common_tags"           { type = map(string) }
variable "service_tags" {
  type = map(map(string))
  default = {
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
    qdrant = {
      Tier        = "data"
      Service     = "qdrant"
      ServicePort = "6333"
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

variable "qdrant_instances" {
  description = "Qdrant 인스턴스 맵 (key = 인스턴스 이름, e.g. primary, replica)"
  type = map(object({
    subnet_id     = string
    private_ip    = optional(string)
    instance_type = optional(string)
    volume_size   = optional(number, 20)
  }))
  default = {}
}
