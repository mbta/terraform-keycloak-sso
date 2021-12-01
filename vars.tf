variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "ecr_keycloak_image_url" {
  type        = string
  description = "ECR Keycloak Image location"
}

variable "environment" {
  type = string
  description = "Name of environment, e.g. 'dev', 'prod'"
}

variable "log_bucket_owner_id" {
  type        = string
  description = "IAM id for the logs bucket owner (differs per region)"
}

variable "public_subnets" {
  description = "List of public subnets"
}

variable "private_subnets" {
  description = "List of private subnets"
}

variable "availability_zones" {
  description = "List of availability zones"
}

variable "db_name" {
  type        = string
  description = "Keycloak database name"
}

variable "db_username" {
  type        = string
  description = "Keycloak database username"
}

variable "db_password" {
  type        = string
  description = "Keycloak database user password"
}

variable "kc_username" {
  type        = string
  description = "Keycloak admin username"
}

variable "kc_password" {
  type        = string
  description = "Keycloak admin user password"
}
