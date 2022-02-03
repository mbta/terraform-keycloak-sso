data "aws_iam_policy_document" "keycloak-ses-sender" {
  statement {
    actions   = ["ses:SendRawEmail", "ses:SendEmail"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "keycloak-ses-sender" {
  name        = "keycloak-${var.environment}-ses-sender"
  description = "Allows sending of e-mails via Simple Email Service"
  policy      = data.aws_iam_policy_document.keycloak-ses-sender.json
}

# Attach to ECS task role
resource "aws_iam_role_policy_attachment" "keycloak-ses-send-mail-policy-attachment" {
  role       = aws_iam_role.keycloak-ecs-execution-task-role.name
  policy_arn = aws_iam_policy.keycloak-ses-sender.arn
}

