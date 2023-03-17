resource "aws_sqs_queue" "keycloak_to_alerts_concierge_user_updates" {
  name = "keycloak-${var.environment}-alerts-concierge-user-updates"
  sqs_managed_sse_enabled = true
}

# allow Keycloak to publish messages to SQS
resource "aws_iam_role_policy" "keycloak_to_alerts_concierge_user_updates_publish" {
  name   = "keycloak-${var.environment}-alerts-concierge-user-updates-publish"
  role   = resource.keycloak-service.keycloak-service.id
  policy = data.aws_iam_policy_document.keycloak_to_alerts_concierge_user_updates_publish.json
}

data "aws_iam_policy_document" "keycloak_to_alerts_concierge_user_updates_publish" {
  statement {
    sid = "AllowSendFromKeycloak"
    effect = "Allow"
    actions = [
      "sqs:GetQueueUrl",
      "sqs:SendMessage"
    ]
    resources = [
      aws_sqs_queue.keycloak_to_alerts_concierge_user_updates.arn
    ]
  }
}
