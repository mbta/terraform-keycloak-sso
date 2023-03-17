resource "aws_sqs_queue" "keycloak_to_alerts_concierge_user_updates" {
  name = "keycloak-${var.environment}-alerts-concierge-user-updates"
  sqs_managed_sse_enabled = true
}

# Allow Keycloak ECS to publish messages to SQS
resource "aws_sqs_queue_policy" "keycloak_to_alerts_concierge_user_updates" {
  queue_url = aws_sqs_queue.keycloak_to_alerts_concierge_user_updates.id
  policy    = data.aws_iam_policy_document.keycloak_to_alerts_concierge_user_updates_policy.json
}
data "aws_iam_policy_document" "keycloak_to_alerts_concierge_user_updates_policy" {
  statement {
    sid = "AllowSendFromKeycloakECS"
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
    actions = [
      "sqs:GetQueueUrl",
      "sqs:SendMessage"
    ]
    resources = [
      aws_sqs_queue.keycloak_to_alerts_concierge_user_updates.arn
    ]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_ecs_task_definition.keycloak-ecs-taskdef.arn]
    }
  }
}
