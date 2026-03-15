terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "moyeo-bab-tfstate-dev"
    key            = "v3/environments/dev/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "moyeo-bab-tf-lock-dev"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}
