locals {
  project     = "moyeobab"
  environment = "prod"
  version     = "v3"

  common_tags = {
    Project     = local.project
    Environment = local.environment
    Version     = local.version
    ManagedBy   = "terraform"
  }
}
