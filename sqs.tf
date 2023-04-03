resource "aws_sqs_queue" "keycloak_to_app_user_updates" {
  for_each = {
    for app in var.applications_to_update
    : app => app
  }
  
  name = "keycloak-${var.environment}-app-user-updates-${each.key}"
  sqs_managed_sse_enabled = true
}

# Allow Keycloak ECS to publish messages to SQS
resource "aws_sqs_queue_policy" "keycloak_to_app_user_updates" {
  for_each = aws_sqs_queue.keycloak_to_app_user_updates

  queue_url = each.value.id
  policy    = data.aws_iam_policy_document.keycloak_to_app_user_updates_policy[each.key].json
}

data "aws_iam_policy_document" "keycloak_to_app_user_updates_policy" {
  for_each = aws_sqs_queue.keycloak_to_app_user_updates
  
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
      each.value.arn
    ]
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_iam_role.keycloak-ecs-execution-task-role.arn]
    }
  }
}
