variable "project"      { type = string }
variable "environment"  { type = string }
variable "app_version"  { type = string }
variable "common_tags"  { type = map(string) }
variable "service_name" { type = string }
variable "service_tags" { type = map(string) }

variable "ami_id"                { type = string }
variable "instance_type" {
  type    = string
  default = "t4g.small"
}
variable "key_name" {
  type    = string
  default = "tasteCompass-key"
}
variable "instance_profile_name" { type = string }
variable "security_group_ids"    { type = list(string) }

variable "user_data" {
  description = "User data script (plain text, base64 인코딩은 모듈 내부에서 처리)"
  type        = string
  default     = ""
}

variable "root_volume_size" {
  type    = number
  default = 20
}

variable "subnet_ids" { type = list(string) }

variable "target_group_arns" {
  type    = list(string)
  default = []
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 2
}

variable "desired_capacity" {
  type    = number
  default = 1
}

variable "health_check_type" {
  type    = string
  default = "EC2"
}

variable "health_check_grace_period" {
  type    = number
  default = 300
}

variable "default_instance_warmup" {
  type    = number
  default = 300
}

variable "enabled_metrics" {
  type = list(string)
  default = [
    "GroupAndWarmPoolDesiredCapacity",
    "GroupAndWarmPoolTotalCapacity",
    "GroupDesiredCapacity",
    "GroupInServiceCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingCapacity",
    "GroupPendingInstances",
    "GroupStandbyCapacity",
    "GroupStandbyInstances",
    "GroupTerminatingCapacity",
    "GroupTerminatingInstances",
    "GroupTerminatingRetainedCapacity",
    "GroupTerminatingRetainedInstances",
    "GroupTotalCapacity",
    "GroupTotalInstances",
    "WarmPoolDesiredCapacity",
    "WarmPoolMinSize",
    "WarmPoolPendingCapacity",
    "WarmPoolPendingRetainedCapacity",
    "WarmPoolTerminatingCapacity",
    "WarmPoolTerminatingRetainedCapacity",
    "WarmPoolTotalCapacity",
    "WarmPoolWarmedCapacity",
  ]
}

variable "min_healthy_percentage" {
  type    = number
  default = 100
}

variable "max_healthy_percentage" {
  type    = number
  default = 110
}
