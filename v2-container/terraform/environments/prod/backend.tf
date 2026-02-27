terraform {
  backend "s3" {
    bucket         = "moyeo-bab-tfstate-prod"
    key            = "v2/environments/prod/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "moyeo-bab-tf-lock-prod"
    encrypt        = true
  }
}
