# =============================================================================
# AZ-c 서브넷 추가 — 3 AZ Multi-AZ 확장
# 기존 v2 VPC에 ap-northeast-2c 서브넷 3개 추가 (public, app, data)
# NAT Gateway 신규 생성 (AZ-c 전용)
# =============================================================================

data "aws_route_table" "public" {
  filter {
    name   = "tag:Name"
    values = ["moyeobab-prod-v2-public-rt"]
  }
}

# --- Public 서브넷 (AZ-c) ---
resource "aws_subnet" "public_c" {
  vpc_id                  = data.aws_vpc.existing.id
  cidr_block              = "10.0.5.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-v2-public-3"
    Tier = "public"
  })
}

resource "aws_route_table_association" "public_c" {
  subnet_id      = aws_subnet.public_c.id
  route_table_id = data.aws_route_table.public.id
}

# --- NAT Gateway (AZ-c) ---
resource "aws_eip" "nat_c" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-v2-nat-3"
  })
}

resource "aws_nat_gateway" "nat_c" {
  allocation_id = aws_eip.nat_c.id
  subnet_id     = aws_subnet.public_c.id

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-v2-nat-3"
  })

  depends_on = [aws_subnet.public_c]
}

# --- Private Route Table (AZ-c) ---
resource "aws_route_table" "private_c" {
  vpc_id = data.aws_vpc.existing.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_c.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-v2-private-rt-3"
  })
}

# --- App 서브넷 (AZ-c) ---
resource "aws_subnet" "app_c" {
  vpc_id            = data.aws_vpc.existing.id
  cidr_block        = "10.0.8.0/24"
  availability_zone = "ap-northeast-2c"

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-v2-private-app-3"
    Tier = "app"
  })
}

resource "aws_route_table_association" "app_c" {
  subnet_id      = aws_subnet.app_c.id
  route_table_id = aws_route_table.private_c.id
}

# --- Data 서브넷 (AZ-c) ---
resource "aws_subnet" "data_c" {
  vpc_id            = data.aws_vpc.existing.id
  cidr_block        = "10.0.9.0/24"
  availability_zone = "ap-northeast-2c"

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-v2-private-data-3"
    Tier = "data"
  })
}

resource "aws_route_table_association" "data_c" {
  subnet_id      = aws_subnet.data_c.id
  route_table_id = aws_route_table.private_c.id
}
