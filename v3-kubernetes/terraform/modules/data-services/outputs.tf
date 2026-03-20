output "rabbitmq_instance_id" { value = aws_instance.rabbitmq.id }
output "rabbitmq_private_ip"  { value = aws_instance.rabbitmq.private_ip }

output "mongodb_instance_id" { value = aws_instance.mongodb.id }
output "mongodb_private_ip"  { value = aws_instance.mongodb.private_ip }
