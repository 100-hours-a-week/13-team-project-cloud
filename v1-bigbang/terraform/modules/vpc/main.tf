resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = merge(
    { Name = var.vpc_name },
    var.vpc_tags
  )
}

resource "aws_subnet" "main" {
  count = length(var.vpc_subnet_cidrs)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.vpc_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    { Name = "${var.vpc_name}-subnet-${count.index + 1}" },
    var.vpc_tags
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    { Name = "${var.vpc_name}-igw" },
    var.vpc_tags
  )
}

resource "aws_default_route_table" "main" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    { Name = "${var.vpc_name}-rt" },
    var.vpc_tags
  )
}
