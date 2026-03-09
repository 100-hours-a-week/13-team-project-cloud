output "vpc_id"         { value = data.aws_vpc.existing.id }
output "k8s_subnet_ids" { value = module.network.k8s_subnet_ids }
output "k8s_node_sg_id" { value = module.security.k8s_node_sg_id }
output "k8s_cp_sg_id"   { value = module.security.k8s_cp_sg_id }

output "control_plane_instances" { value = module.compute.control_plane_instances }
output "worker_instances"        { value = module.compute.worker_instances }
