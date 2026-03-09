output "k8s_node_sg_id" { value = aws_security_group.k8s_node.id }
output "k8s_cp_sg_id"   { value = aws_security_group.k8s_cp.id }
