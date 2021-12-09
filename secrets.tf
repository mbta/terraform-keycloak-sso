resource "aws_secretsmanager_secret" "keycloak-admin-password" {
  name = "keycloak-${var.environment}-admin-password"

  tags = var.tags
}

resource "aws_secretsmanager_secret" "keycloak-database-password" {
  name = "keycloak-${var.environment}-db-password"

  tags = var.tags
}
