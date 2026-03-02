# =============================================================================
# Dev VPC 참조 (dev state 없이 직접 조회)
# =============================================================================
data "aws_vpc" "dev" {
  tags = {
    Name = "moyeobab-dev-v2"
  }
}

# dev 환경 SG 참조 (Loki ingress, scraping egress용)
data "aws_security_group" "dev_app" {
  name   = "moyeobab-dev-app-v2-sg"
  vpc_id = data.aws_vpc.dev.id
}

data "aws_security_group" "dev_data" {
  name   = "moyeobab-dev-data-sg"
  vpc_id = data.aws_vpc.dev.id
}

# dev private route table 참조 (monitoring 서브넷 연결용)
data "aws_route_table" "dev_private" {
  tags = {
    Name = "moyeobab-dev-v2-private-rt-1"
  }
}

# dev compute IAM instance profile 참조 (현재 monitoring 인스턴스가 사용 중)
data "aws_iam_instance_profile" "dev_ec2" {
  name = "moyeobab-v2-dev-ec2-profile"
}

# =============================================================================
# Monitoring 전용 프라이빗 서브넷 (dev VPC 내)
# dev private app: 10.1.1.0/24
# dev private data: 10.1.2.0/24
# monitoring:       10.1.5.0/24
# =============================================================================
resource "aws_subnet" "monitoring" {
  vpc_id            = data.aws_vpc.dev.id
  cidr_block        = "10.1.5.0/24"
  availability_zone = "ap-northeast-2a"

  tags = {
    Name      = "moyeobab-monitoring-v2-subnet"
    Project   = var.project
    ManagedBy = "terraform"
  }
}

resource "aws_route_table_association" "monitoring" {
  subnet_id      = aws_subnet.monitoring.id
  route_table_id = data.aws_route_table.dev_private.id
}

# =============================================================================
# Monitoring EC2 Instance (Prometheus + Grafana + Loki)
# =============================================================================
resource "aws_instance" "monitoring" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.monitoring.id
  key_name               = var.ec2_key_name
  vpc_security_group_ids = [aws_security_group.monitoring.id]
  iam_instance_profile   = data.aws_iam_instance_profile.dev_ec2.name

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    iops                  = 3000
    throughput            = 125
    delete_on_termination = false
  }

  tags = {
    Name      = "moyeobab-monitoring-v2"
    Project   = var.project
    Version   = "v2"
    ManagedBy = "terraform"
    Service   = "monitoring"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ami]
  }
}
