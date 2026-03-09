output "k8s_node_role_id"              { value = aws_iam_role.k8s_node.id }
output "k8s_node_instance_profile_name" { value = aws_iam_instance_profile.k8s_node.name }
