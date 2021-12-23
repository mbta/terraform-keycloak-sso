variable "acm_certificate_arn" {
  type        = string
  description = "(optional) ARN of certificate for load balancer to use. Defaults to auto-creating a new certificate"
  default     = null
}

variable "acm_hostname" {
  type        = string
  description = "(optional) DNS hostname of the Keycloak instance. Only needed if generating a certificate within this module"
  default     = "keycloak.example.com"
}

variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "database_subnet_group" {
  type        = string
  description = "(optional) Name of a database subnet group where Keycloak MariaDB instance will reside. Defaults to creating a new subnet group containing var.private_subnets"
  default     = null
}

variable "db_name" {
  type        = string
  description = "Keycloak database name"
}

variable "db_username" {
  type        = string
  description = "Keycloak database username"
}

variable "ecr_keycloak_image_url" {
  type        = string
  description = "(optional) ECR Keycloak Image location. Defaults to creating a new ECR repo"
  default     = null
}

variable "ecr_keycloak_image_tag" {
  type        = string
  description = "(optional) ECR Keycloak image tag. Defaults to 'latest'"
  default     = "latest"
}

variable "ecs_cluster_name" {
  type        = string
  description = "(optional) Name of an existing ECS cluster. Defaults to creating a new ECS cluster with the name 'keycloak-$${var.environment}-cluster'"
  default     = null
}

variable "environment" {
  type        = string
  description = "Name of environment, e.g. 'dev', 'prod'"
}

variable "kc_username" {
  type        = string
  description = "Keycloak admin username"
}

variable "lb_access_logs_s3_bucket" {
  type        = string
  description = "(optional) Name of S3 bucket where logs will be stored. Defaults to creating a new S3 bucket"
  default     = null
}

variable "organization" {
  type        = string
  description = "The name of the organization that owns this Keycloak instance"
}

variable "private_subnets" {
  type        = list(string)
  description = "List of private subnets in the VPC where Keycloak will reside"
}

variable "public_subnets" {
  type        = list(string)
  description = "List of public subnets in the VPC where Keycloak will reside"
}

variable "tags" {
  type        = map(string)
  description = "Map of tags to add to all resources. Defaults to `{ Project = 'Keycloak' }`"
  default     = { Project = "Keycloak" }
}

variable "vpc_id" {
  type        = string
  description = "ID of an existing VPC where Keycloak will reside"
}
