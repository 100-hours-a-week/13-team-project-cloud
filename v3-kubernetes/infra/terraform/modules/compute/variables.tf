variable "project"     { type = string }
variable "environment" { type = string }
variable "app_version" { type = string }
variable "common_tags" { type = map(string) }

variable "ec2_ami_id"             { type = string }
variable "instance_profile_name"  { type = string }
variable "k8s_subnet_ids"         { type = list(string) }
variable "k8s_node_sg_id"         { type = string }
variable "k8s_cp_sg_id"           { type = string }

variable "default_instance_type" {
  type    = string
  default = "t4g.medium"
}

variable "control_plane_instances" {
  description = "Control Plane 인스턴스 정의"
  type = map(object({
    subnet_index  = number
    private_ip    = optional(string)
    instance_type = optional(string)
    volume_size   = optional(number, 30)
  }))
}

variable "worker_instances" {
  description = "Worker 노드 인스턴스 정의"
  type = map(object({
    subnet_index  = number
    private_ip    = optional(string)
    instance_type = optional(string)
    volume_size   = optional(number, 30)
  }))
}
