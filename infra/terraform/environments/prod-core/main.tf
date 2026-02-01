resource "aws_eip" "app" {
  domain = "vpc"

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(
    { Name = "${var.core_name}-eip" },
    var.core_tags
  )
}

resource "aws_ebs_volume" "db" {
  availability_zone = var.db_availability_zone
  size              = var.db_volume_size
  type              = var.db_volume_type
  final_snapshot    = true

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(
    { Name = "${var.core_name}-db" },
    var.core_tags
  )
}

output "eip_allocation_id" {
  description = "Elastic IP allocation ID"
  value       = aws_eip.app.id
}

output "eip_public_ip" {
  description = "Elastic IP public IP"
  value       = aws_eip.app.public_ip
}

output "db_volume_id" {
  description = "DB EBS volume ID"
  value       = aws_ebs_volume.db.id
}

output "db_availability_zone" {
  description = "DB EBS availability zone"
  value       = aws_ebs_volume.db.availability_zone
}
