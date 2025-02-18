provider "aws" {
  region = var.aws_region
}

terraform {
  required_version = ">= 1.1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.86.0"
    }
  }
}

data "aws_caller_identity" "current" {}
