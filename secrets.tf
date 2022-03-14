locals {
  keycloak_splunk_token_secret_arn = var.splunk_token_secret_arn == null ? join("", aws_secretsmanager_secret.keycloak-splunk-token.*.arn) : var.splunk_token_secret_arn
}

resource "aws_secretsmanager_secret" "keycloak-admin-password" {
  name = "keycloak-${var.environment}-admin-password"

  tags = var.tags
}

resource "aws_secretsmanager_secret" "keycloak-database-password" {
  name = "keycloak-${var.environment}-db-password"

  tags = var.tags
}

# if log driver is Splunk, also create Splunk token secret
resource "aws_secretsmanager_secret" "keycloak-splunk-token" {
  count = var.log_driver == "splunk" && var.splunk_token_secret_arn == null ? 1 : 0

  name        = "keycloak-splunk-token"
  description = "Keycloak Splunk HTTP Event Collector token"

  tags = var.tags
}
