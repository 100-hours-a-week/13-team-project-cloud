output "monitoring_instance_id" {
  description = "Monitoring EC2 instance ID"
  value       = module.monitoring_instance.instance_id
}

output "monitoring_public_ip" {
  description = "Monitoring EC2 public IP"
  value       = module.monitoring_instance.public_ip
}

output "monitoring_private_ip" {
  description = "Monitoring EC2 private IP"
  value       = module.monitoring_instance.private_ip
}

output "monitoring_public_dns" {
  description = "Monitoring EC2 public DNS"
  value       = module.monitoring_instance.public_dns
}

output "monitoring_security_group_id" {
  description = "Monitoring security group ID"
  value       = module.monitoring_instance.security_group_id
}
