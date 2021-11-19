provider "aws" { 
   region= var.aws_region
}

terraform {
   required_version = ">= 1.0.8"
}

data "aws_vpc" "default" {
   default = true
}

data "aws_subnet_ids" "all" {
   vpc_id = data.aws_vpc.default.id
}

