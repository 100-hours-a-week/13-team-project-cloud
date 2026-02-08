terraform {
  backend "s3" {
    bucket         = "moyeo-bab-tfstate-dev"
    key            = "environments/dev-core/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "moyeo-bab-tf-lock-dev"
    encrypt        = true
  }
}
