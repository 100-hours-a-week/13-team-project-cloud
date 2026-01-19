module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr           = var.vpc_cidr
  vpc_name           = var.vpc_name
  availability_zones = var.availability_zones
  vpc_subnet_cidrs   = var.vpc_subnet_cidrs
  vpc_tags           = var.vpc_tags
}
