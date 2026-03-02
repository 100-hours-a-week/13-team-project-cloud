# =============================================================================
# Backend Server 1 (Spring Boot 메인 백엔드)
# NOTE: ASG 사용 시 enable_backend = false로 비활성화
# =============================================================================
resource "aws_instance" "backend_1" {
  count = var.enable_backend ? 1 : 0

  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = var.private_app_subnet_id
  private_ip             = var.backend_private_ip
  key_name               = var.ec2_key_name
  vpc_security_group_ids = compact([var.app_sg_id, var.app_monitoring_sg_id])
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = false
  }

  tags = merge(var.common_tags, var.service_tags.backend, {
    Name = "${var.project}-${var.environment}-${var.app_version}-backend-1"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ami]
  }
}

# =============================================================================
# Backend Server 2 (조건부 — enable_backend_2 = true일 때만 생성)
# =============================================================================
resource "aws_instance" "backend_2" {
  count = var.enable_backend && var.enable_backend_2 ? 1 : 0

  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = var.private_app_subnet_id
  key_name               = var.ec2_key_name
  vpc_security_group_ids = compact([var.app_sg_id, var.app_monitoring_sg_id])
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = false
  }

  tags = merge(var.common_tags, var.service_tags.backend, {
    Name = "${var.project}-${var.environment}-${var.app_version}-backend-2"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ami]
  }
}

# =============================================================================
# Recommend Server (FastAPI 추천 서비스)
# =============================================================================
resource "aws_instance" "recommend" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = var.private_app_subnet_id
  private_ip             = var.recommend_private_ip
  key_name               = var.ec2_key_name
  vpc_security_group_ids = compact([var.app_sg_id, var.app_monitoring_sg_id])
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = false
  }

  tags = merge(var.common_tags, var.service_tags.recommend, {
    Name = "${var.project}-${var.environment}-${var.app_version}-recommend"
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ami]
  }
}

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
