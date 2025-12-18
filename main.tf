provider "aws" {
  region = var.aws_region
}

terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6"
    }
  }
}

data "aws_caller_identity" "current" {}
