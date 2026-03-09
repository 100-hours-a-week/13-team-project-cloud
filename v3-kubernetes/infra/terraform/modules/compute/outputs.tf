output "control_plane_instances" {
  value = {
    for key, instance in aws_instance.control_plane : key => {
      id         = instance.id
      private_ip = instance.private_ip
    }
  }
}

output "worker_instances" {
  value = {
    for key, instance in aws_instance.worker : key => {
      id         = instance.id
      private_ip = instance.private_ip
    }
  }
}
