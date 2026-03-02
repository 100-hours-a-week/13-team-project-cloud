# =============================================================================
# PostgreSQL Servers
# =============================================================================
resource "aws_instance" "postgresql" {
  for_each = var.postgresql_instances

  ami                    = var.ec2_ami_id
  instance_type          = coalesce(each.value.instance_type, var.ec2_instance_type)
  subnet_id              = each.value.subnet_id
  private_ip             = each.value.private_ip
  key_name               = var.ec2_key_name
  vpc_security_group_ids = compact([var.data_sg_id, var.data_monitoring_sg_id])
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size           = each.value.volume_size
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = false
  }

  tags = merge(var.common_tags, var.service_tags.postgresql, {
    Name = "${var.project}-${var.environment}-${var.app_version}-postgresql-${each.key}"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ami]
  }
}

# =============================================================================
# Redis Servers
# =============================================================================
resource "aws_instance" "redis" {
  for_each = var.redis_instances

  ami                    = var.ec2_ami_id
  instance_type          = coalesce(each.value.instance_type, var.ec2_instance_type)
  subnet_id              = each.value.subnet_id
  private_ip             = each.value.private_ip
  key_name               = var.ec2_key_name
  vpc_security_group_ids = compact([var.data_sg_id, var.data_monitoring_sg_id])
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size           = each.value.volume_size
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = false
  }

  tags = merge(var.common_tags, var.service_tags.redis, {
    Name = "${var.project}-${var.environment}-${var.app_version}-redis-${each.key}"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ami]
  }
}

# =============================================================================
# Qdrant Servers
# =============================================================================
resource "aws_instance" "qdrant" {
  for_each = var.qdrant_instances

  ami                    = var.ec2_ami_id
  instance_type          = coalesce(each.value.instance_type, var.ec2_instance_type)
  subnet_id              = each.value.subnet_id
  private_ip             = each.value.private_ip
  key_name               = var.ec2_key_name
  vpc_security_group_ids = compact([var.data_sg_id, var.data_monitoring_sg_id])
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size           = each.value.volume_size
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = false
  }

  tags = merge(var.common_tags, var.service_tags.qdrant, {
    Name = "${var.project}-${var.environment}-${var.app_version}-qdrant-${each.key}"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ami]
  }
}

# =============================================================================
# IAM Role (SSM + ECR pull)
# =============================================================================
resource "aws_iam_role" "ec2" {
  name = "${var.project}-${var.app_version}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ec2_ecr" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-${var.app_version}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
}
