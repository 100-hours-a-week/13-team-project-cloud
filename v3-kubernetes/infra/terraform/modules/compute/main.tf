# =============================================================================
# Control Plane Instances
# =============================================================================
resource "aws_instance" "control_plane" {
  for_each = var.control_plane_instances

  ami                    = var.ec2_ami_id
  instance_type          = coalesce(each.value.instance_type, var.default_instance_type)
  subnet_id              = var.k8s_subnet_ids[each.value.subnet_index]
  private_ip             = each.value.private_ip
  iam_instance_profile   = var.instance_profile_name
  vpc_security_group_ids = [var.k8s_node_sg_id, var.k8s_cp_sg_id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = each.value.volume_size
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
  }

  tags = merge(var.common_tags, {
    Name              = "${var.project}-${var.environment}-${var.app_version}-k8s-${each.key}"
    KubernetesRole    = "control-plane"
    KubernetesCluster = "${var.project}-${var.environment}"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

# =============================================================================
# Worker Node Instances
# =============================================================================
resource "aws_instance" "worker" {
  for_each = var.worker_instances

  ami                    = var.ec2_ami_id
  instance_type          = coalesce(each.value.instance_type, var.default_instance_type)
  subnet_id              = var.k8s_subnet_ids[each.value.subnet_index]
  private_ip             = each.value.private_ip
  iam_instance_profile   = var.instance_profile_name
  vpc_security_group_ids = [var.k8s_node_sg_id]

  root_block_device {
    volume_type           = "gp3"
    volume_size           = each.value.volume_size
    iops                  = 3000
    throughput            = 125
    delete_on_termination = true
  }

  tags = merge(var.common_tags, {
    Name              = "${var.project}-${var.environment}-${var.app_version}-k8s-${each.key}"
    KubernetesRole    = "worker"
    KubernetesCluster = "${var.project}-${var.environment}"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}
