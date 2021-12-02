variable "acm_certificate_arn" {
  type        = string
  description = "(optional) ARN of certificate for load balancer to use. Defaults to auto-creating a new certificate"
  default     = null
}

variable "availability_zones" {
  description = "List of availability zones"
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

variable "ecs_cluster_arn" {
  type        = string
  description = "(optional) ARN of an existing ECS cluster. Defaults to creating a new ECS cluster"
}

variable "environment" {
  type        = string
  description = "Name of environment, e.g. 'dev', 'prod'"
}

variable "hostname" {
  type        = string
  description = "(optional) DNS hostname of the Keycloak instance. Only needed if generating a certificate within this module"
  default     = "keycloak.example.com"
}

variable "kc_username" {
  type        = string
  description = "Keycloak admin username"
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

variable "vpc_id" {
  type        = string
  description = "ID of an existing VPC where Keycloak will reside"
}
