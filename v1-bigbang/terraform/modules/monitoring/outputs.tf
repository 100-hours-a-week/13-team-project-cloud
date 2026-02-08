output "instance_id" {
  description = "Monitoring EC2 instance ID"
  value       = aws_instance.monitoring.id
}

output "public_ip" {
  description = "Monitoring EC2 public IP"
  value       = aws_instance.monitoring.public_ip
}

output "private_ip" {
  description = "Monitoring EC2 private IP"
  value       = aws_instance.monitoring.private_ip
}

output "public_dns" {
  description = "Monitoring EC2 public DNS"
  value       = aws_instance.monitoring.public_dns
}

output "security_group_id" {
  description = "Monitoring security group ID"
  value       = aws_security_group.monitoring.id
}
