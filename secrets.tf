locals {
  keycloak_splunk_token_secret_arn = var.splunk_token_secret_arn == null ? join("", aws_secretsmanager_secret.keycloak-splunk-token.*.arn) : var.splunk_token_secret_arn
}

ephemeral "random_password" "default_admin_password" {
  count  = var.set_passwords ? 1 : 0
  length = 32
}

resource "aws_secretsmanager_secret_version" "default_admin_password" {
  count                    = var.set_passwords ? 1 : 0
  secret_id                = aws_secretsmanager_secret.keycloak-admin-password.id
  secret_string_wo         = ephemeral.random_password.default_admin_password[0].result
  secret_string_wo_version = 1
}

resource "aws_secretsmanager_secret" "keycloak-admin-password" {
  name                    = "keycloak-${var.environment}-admin-password"
  recovery_window_in_days = var.is_temporary ? 0 : 30

  tags = var.tags
}

resource "aws_secretsmanager_secret" "keycloak-database-password" {
  name                    = "keycloak-${var.environment}-db-password"
  recovery_window_in_days = var.is_temporary ? 0 : 30

  tags = var.tags
}

# if log driver is Splunk, also create Splunk token secret
resource "aws_secretsmanager_secret" "keycloak-splunk-token" {
  count = var.log_driver == "splunk" && var.splunk_token_secret_arn == null ? 1 : 0

  name                    = "keycloak-splunk-token"
  description             = "Keycloak Splunk HTTP Event Collector token"
  recovery_window_in_days = var.is_temporary ? 0 : 30

  tags = var.tags
}
