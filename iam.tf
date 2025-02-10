locals {
  splunk_token_secret_arn_list = var.log_driver == "splunk" ? [local.keycloak_splunk_token_secret_arn] : []
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "keycloak-ecs-execution-task-role" {
  name               = "keycloak-${var.environment}-ecs-execution-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs-execution-task-policy" {
  role       = aws_iam_role.keycloak-ecs-execution-task-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "keycloak-db-monitoring-role" {

  name = "keycloak-${var.environment}-db-monitoring-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "keycloak-db-monitoring-role" {
  role       = aws_iam_role.keycloak-db-monitoring-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# inline policy for Secrets Manager access, attached to the task execution role created by the ECS module
resource "aws_iam_role_policy" "inline-keycloak-secretsmanager" {
  name   = "secretsmanager-keycloak-${var.environment}"
  role   = aws_iam_role.keycloak-ecs-execution-task-role.name
  policy = data.aws_iam_policy_document.inline-keycloak-secretsmanager-doc.json
}

# iam policy document for inline-keycloak-secretsmanager above
data "aws_iam_policy_document" "inline-keycloak-secretsmanager-doc" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    effect  = "Allow"
    resources = concat(
      [
        aws_secretsmanager_secret.keycloak-admin-password.arn,
        aws_secretsmanager_secret.keycloak-database-password.arn,
      ],
      local.splunk_token_secret_arn_list
    )
  }
}

# allow Keycloak to publish messages to SQS
resource "aws_iam_role_policy" "keycloak_to_app_user_updates_publish" {
  count  = length(var.applications_to_update) > 0 ? 1 : 0
  name   = "keycloak-${var.environment}-app-user-updates-publish"
  role   = aws_iam_role.keycloak-ecs-execution-task-role.name
  policy = data.aws_iam_policy_document.keycloak_to_app_user_updates_publish.json
}

data "aws_iam_policy_document" "keycloak_to_app_user_updates_publish" {
  statement {
    sid = "AllowSendFromKeycloak"
    effect = "Allow"
    actions = [
      "sqs:GetQueueUrl",
      "sqs:SendMessage"
    ]
    resources = [ for queue in aws_sqs_queue.keycloak_to_app_user_updates : queue.arn ]
  }
}
