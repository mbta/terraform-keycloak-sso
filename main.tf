provider "aws" {
  region = var.aws_region
}

terraform {
  required_version = ">= 1.0.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.66.0"
    }
  }
}

data "aws_caller_identity" "current" {}
