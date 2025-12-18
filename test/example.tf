terraform {
  backend "local" {
    path = "/tmp/terraform-keycloak-sso.tfstate"
  }
}

locals {
  name     = "terraform-keycloak-sso"
  vpc_cidr = "10.0.0.0/24"
  region   = "us-east-2"
  az_count = 2
  azs      = slice(data.aws_availability_zones.available.names, 0, local.az_count)
}

output "lb_hostname" {
  value = module.example.alb_endpoint
}
provider "aws" {
  region = local.region

  default_tags {
    tags = {
      Project   = local.name
      Terraform = true
    }

  }
}

data "http" "myip" {
  url = "https://ipv4.icanhazip.com/"
}

data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_secretsmanager_secret_version" "admin_password" {
  secret_id = module.example.admin_password_secret_id
}

output "admin_password" {
  value = nonsensitive(data.aws_secretsmanager_secret_version.admin_password.secret_string)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.1"

  name            = local.name
  cidr            = local.vpc_cidr
  azs             = local.azs
  public_subnets  = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, 4 + k)]

  enable_nat_gateway = true # needed for Fargate to access AWS services
}

module "example" {
  source        = "./.."
  is_temporary  = true
  set_passwords = true

  aws_region     = local.region
  aws_jms_queues = ""

  db_name               = "keycloak"
  db_username           = "keycloak"
  lb_enable_access_logs = false

  organization = local.name
  environment  = "test"

  vpc_id          = module.vpc.vpc_id
  private_subnets = module.vpc.private_subnets
  public_subnets  = module.vpc.public_subnets

  ecr_keycloak_image_url        = "quay.io/keycloak/keycloak"
  ecr_keycloak_image_tag        = "26.3"
  ecr_keycloak_image_entrypoint = ["/opt/keycloak/bin/kc.sh", "start-dev"]

  acm_hostname = "${local.name}.local"
  admin_cidrs = [
    "${chomp(data.http.myip.response_body)}/32",
    "127.0.0.1/32",
    "127.0.0.2/32",
    "127.0.0.3/32",
    "127.0.0.4/32",
    "127.0.0.5/32",
    "127.0.0.6/32",
  ]

  kc_username = "admin"

  autoscale = {
    autoscale_max_capacity = 1
    service_desired_count  = 1
    metric_name            = "CPUUtilization"
    datapoints_to_alarm    = 1
    evaluation_periods     = 1
    period                 = 60
    cooldown               = 60
    adjustment_type        = "ChangeInCapacity"
    statistic              = "Average"
    aggregation_type       = "Average"
    ### Cloudwatch Alaram Scale up and Scale down ###
    scale_up_threshold   = 70
    scale_down_threshold = 40
    ### AutoScale Policy Scale up ###
    scale_up_comparison_operator  = "GreaterThanOrEqualToThreshold"
    scale_up_interval_lower_bound = 1
    scale_up_adjustment           = 1
    ### AutoScale Policy Scale down ###
    scale_down_comparison_operator  = "LessThanThreshold"
    scale_down_interval_lower_bound = 0
    scale_down_adjustment           = -1
  }
}
