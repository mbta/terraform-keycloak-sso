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

variable "autoscale" {
  description = "Autoscaling block"
  type        = map(string)
  default     = {}
}

variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "aws_jms_queues" {
  type        = string
  description = "AWS JMS queue names (comma separated)"
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

variable "lb_enable_access_logs" {
  type        = bool
  description = "Whether to enable access logging to S3"
  default     = true
}

variable "lb_access_logs_s3_bucket" {
  type        = string
  description = "(optional) Name of S3 bucket where logs will be stored. Defaults to creating a new S3 bucket if lb_enable_access_logs is enabled"
  default     = null
}

variable "log_driver" {
  type        = string
  description = "(optional) ECS log driver for task log configuration. Supported options are 'awslogs' and 'splunk'"
  default     = "awslogs"
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

variable "splunk_http_endpoint" {
  type        = string
  description = "(optional) The Splunk HTTP endpoint to send logs to. Only required if log_driver is 'splunk'"
  default     = null
}

variable "splunk_token_secret_arn" {
  type        = string
  description = "(optional) The ARN of a Secrets Manager secret containing the Splunk token. Only required if log_driver is 'splunk' and you wish to use an existing Secrets Manager resource instead of having the module create one"
  default     = null
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

variable "applications_to_update" {
  type        = list(string)
  description = "A list of application names that need to receive updates about user account changes."
  default     = []
}

variable "backup_retention_period" {
  type        = number
  description = "How long to store RDS DB backups"
  default     = null
}
