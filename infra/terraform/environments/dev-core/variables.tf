variable "core_name" {
  description = "Name prefix for core resources"
  type        = string
}

variable "core_tags" {
  description = "Tags to apply to core resources"
  type        = map(string)
}

variable "db_volume_size" {
  description = "DB EBS volume size in GiB"
  type        = number
}

variable "db_volume_type" {
  description = "DB EBS volume type"
  type        = string
}

variable "db_availability_zone" {
  description = "Availability zone for the DB EBS volume"
  type        = string
}
