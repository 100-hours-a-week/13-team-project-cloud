terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "moyeo-bab-tfstate-prod"
    key            = "v3/environments/prod/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "moyeo-bab-tf-lock-prod"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}
