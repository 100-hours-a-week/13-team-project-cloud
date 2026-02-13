# =============================================================================
# VPC (v1에서 소유권 이전 — state rm 후 import)
# =============================================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-igw"
  })
}

# =============================================================================
# Public Subnets (ALB, NAT Gateway)
# =============================================================================
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-public-v2-${count.index + 1}"
    Tier = "public"
  })
}

# =============================================================================
# Private Subnets — App Tier (API, Recommend)
# =============================================================================
resource "aws_subnet" "private_app" {
  count = length(var.private_app_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-private-app-v2-${count.index + 1}"
    Tier = "app"
  })
}

# =============================================================================
# Private Subnets — Data Tier (PostgreSQL, Redis)
# =============================================================================
resource "aws_subnet" "private_data" {
  count = length(var.private_data_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-private-data-v2-${count.index + 1}"
    Tier = "data"
  })
}

# =============================================================================
# Route Tables
# =============================================================================

# Public Route Table (VPC default RT — 0.0.0.0/0 → IGW)
# NOTE: aws_default_route_table import이 provider v6에서 동작하지 않아
#       aws_route_table로 관리. 기존 default RT를 그대로 import.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-public-rt"
  })
}

# Public subnet associations (v2 서브넷만 관리, v1 서브넷 association은 v1 state에 유지)
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table (0.0.0.0/0 → NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-private-rt"
  })
}

resource "aws_route_table_association" "private_app" {
  count = length(aws_subnet.private_app)

  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_data" {
  count = length(aws_subnet.private_data)

  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private.id
}

# =============================================================================
# NAT Gateway
# =============================================================================
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-nat-eip"
  })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.common_tags, {
    Name = "${local.project}-${local.environment}-nat"
  })

  depends_on = [aws_internet_gateway.main]
}
