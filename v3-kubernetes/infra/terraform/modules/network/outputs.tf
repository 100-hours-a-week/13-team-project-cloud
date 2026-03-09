output "k8s_subnet_ids" { value = aws_subnet.k8s[*].id }
