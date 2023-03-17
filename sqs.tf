resource "aws_sqs_queue" "keycloak_to_alerts_concierge_user_updates" {
  name = "keycloak-${var.environment}-alerts-concierge-user-updates"
  sqs_managed_sse_enabled = true
}
