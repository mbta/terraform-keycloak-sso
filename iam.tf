data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs-execution-task-role" {
   name = "keycloak-${var.environment}-ecs-execution-task-role"
   assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json

   tags = {
     project        = "MBTA-Keycloak"
     Name           = "Keycloak-ECS-Exec-Role" 
   }
}

resource "aws_iam_role_policy_attachment" "ecs-execution-task-policy" {
  role       = aws_iam_role.ecs-execution-task-role.name
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

  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"]

  tags = {
    project        = "MBTA-Keycloak"
    Name = "Keycloak-DB-Monitoring-Role"
  }
}

