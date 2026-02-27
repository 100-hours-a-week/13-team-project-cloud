# =============================================================================
# Launch Template
# =============================================================================
resource "aws_launch_template" "this" {
  name          = "${var.project}-${var.app_version}-${var.service_name}-${var.environment}-lt"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
    device_index    = 0
    security_groups = var.security_group_ids
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = "gp3"
      iops                  = 3000
      throughput            = 125
      delete_on_termination = true
    }
  }

  user_data = var.user_data != "" ? base64encode(var.user_data) : null

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.common_tags, var.service_tags, {
      Name = "${var.project}-${var.environment}-${var.app_version}-${var.service_name}"
    })
  }

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-${var.app_version}-${var.service_name}-lt"
  })

  lifecycle {
    ignore_changes = [image_id]
  }
}

# =============================================================================
# Auto Scaling Group
# =============================================================================
resource "aws_autoscaling_group" "this" {
  name                = "${var.project}-${var.app_version}-${var.service_name}-${var.environment}-asg"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = var.target_group_arns

  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period
  default_instance_warmup   = var.default_instance_warmup

  enabled_metrics = var.enabled_metrics

  instance_maintenance_policy {
    min_healthy_percentage = var.min_healthy_percentage
    max_healthy_percentage = var.max_healthy_percentage
  }

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge(var.common_tags, var.service_tags, {
      Name = "${var.project}-${var.environment}-${var.app_version}-${var.service_name}"
    })

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
