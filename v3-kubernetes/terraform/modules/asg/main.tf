# =============================================================================
# Launch Template — Worker 노드 템플릿
# =============================================================================
resource "aws_launch_template" "wp" {
  name = "${var.project}-${var.environment}-${var.app_version}-k8s-wp-lt"

  image_id      = var.ec2_ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.instance_profile_name
  }

  vpc_security_group_ids = [var.k8s_node_sg_id]

  user_data = base64encode(templatefile("${path.module}/templates/wp-user-data.sh", {
    deploy_env = var.deploy_env
  }))

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_type           = "gp3"
      volume_size           = var.volume_size
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.common_tags, {
      Name              = "${var.project}-${var.environment}-${var.app_version}-k8s-wp"
      KubernetesRole    = "worker"
      KubernetesCluster = "${var.project}-${var.environment}"
    })
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-k8s-wp-lt"
  })
}

# =============================================================================
# Auto Scaling Group — Worker 노드 오토스케일링
# =============================================================================
resource "aws_autoscaling_group" "wp" {
  name = "${var.project}-${var.environment}-${var.app_version}-k8s-wp-asg"

  launch_template {
    id      = aws_launch_template.wp.id
    version = "$Latest"
  }

  vpc_zone_identifier = var.subnet_ids

  desired_capacity = var.desired_capacity
  min_size         = var.min_size
  max_size         = var.max_size

  target_group_arns = var.target_group_arns

  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "${var.project}-${var.environment}-${var.app_version}-k8s-wp"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.common_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  tag {
    key                 = "KubernetesRole"
    value               = "worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "KubernetesCluster"
    value               = "${var.project}-${var.environment}"
    propagate_at_launch = true
  }
}
