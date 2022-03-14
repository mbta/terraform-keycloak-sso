# define various task definition log configuration option blocks
# and use a module var to switch between different log drivers
locals {
  all_log_configurations = {
    awslogs = {
      logDriver = "awslogs",
      options = {
        awslogs-group         = join("", aws_cloudwatch_log_group.keycloak-log-group.*.id),
        awslogs-region        = var.aws_region,
        awslogs-stream-prefix = "log"
      }
    },
    splunk = {
      logDriver = "splunk",
      options = {
        splunk-url    = var.splunk_http_endpoint,
        splunk-index  = "keycloak-${var.environment}"
        splunk-format = "raw"
      }
      secretOptions = [
        {
          name      = "splunk-token",
          valueFrom = local.keycloak_splunk_token_secret_arn
        }
      ]
    }
  }

  # the value of log_driver determines which of the above configuration blocks to use
  log_configuration = jsonencode(local.all_log_configurations[var.log_driver])
}

# if log driver is CloudWatch, create log group
resource "aws_cloudwatch_log_group" "keycloak-log-group" {
  count = var.log_driver == "awslogs" ? 1 : 0

  name              = "keycloak-${var.environment}-logs"
  retention_in_days = 30

  tags = var.tags
}
