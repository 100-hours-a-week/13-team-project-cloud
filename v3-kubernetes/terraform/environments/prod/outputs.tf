output "vpc_id"         { value = data.aws_vpc.existing.id }
output "app_subnet_ids" { value = data.aws_subnets.app.ids }
output "k8s_node_sg_id" { value = module.security.k8s_node_sg_id }
output "k8s_cp_sg_id"   { value = module.security.k8s_cp_sg_id }

output "control_plane_instances" { value = module.compute.control_plane_instances }

output "asg_name" { value = module.asg.asg_name }

output "nlb_dns_name" { value = module.nlb.nlb_dns_name }
