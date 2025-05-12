# terraform/backend.tf
terraform {
  backend "s3" {
    bucket         = "woocommerce-gitops-terraform-state"
    key            = "woocommerce/terraform.tfstate"
    region         = "ap-southeast-2"
    dynamodb_table = "woocommerce-gitops-terraform-locks"
    encrypt        = true
  }
}