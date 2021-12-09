provider "aws" {
  region = var.aws_region
}

terraform {
  required_version = ">= 1.0.8"
}

data "aws_caller_identity" "current" {}
