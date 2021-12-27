resource "aws_iam_role" "keycloak-ecs-autoscale-role" {
  name = "keycloak-ecs-scale-application"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "application-autoscaling.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "keycloak-ecs-autoscale" {
  role       = aws_iam_role.keycloak-ecs-autoscale-role.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceAutoscaleRole"
}


# CLOUDWATCH ALARM to monitor the memory utilization of a service
resource "aws_cloudwatch_metric_alarm" "keycloak-alarm-scale-down" {
  alarm_description = "Scale down alarm for keycloak-service"
  namespace         = "AWS/ECS"
  alarm_name        = "keycloak-service-down"
  alarm_actions     = [aws_appautoscaling_policy.keycloak-policy-scale-down.arn]

  comparison_operator = var.autoscale["scale_down_comparison_operator"]
  threshold           = var.autoscale["scale_down_threshold"]
  evaluation_periods  = var.autoscale["evaluation_periods"]
  metric_name         = var.autoscale["metric_name"]
  period              = lookup(var.autoscale, "period", 180)
  statistic           = lookup(var.autoscale, "statistic", "Average")
  datapoints_to_alarm = lookup(var.autoscale, "datapoints_to_alarm", 3)

  dimensions = {
    ClusterName = local.keycloak_ecs_cluster_name
    ServiceName = aws_ecs_service.keycloak-service.name
  }
}

# CLOUDWATCH ALARM  to monitor memory utilization of a service
resource "aws_cloudwatch_metric_alarm" "keycloak-alarm-scale-up" {
  alarm_description = "Scale up alarm for keycloak-service"
  namespace         = "AWS/ECS"
  alarm_name        = "keycloak-service-up"
  alarm_actions     = [aws_appautoscaling_policy.keycloak-policy-scale-up.arn]

  comparison_operator = var.autoscale["scale_up_comparison_operator"]
  threshold           = var.autoscale["scale_up_threshold"]
  evaluation_periods  = var.autoscale["evaluation_periods"]
  metric_name         = var.autoscale["metric_name"]
  period              = lookup(var.autoscale, "period", 180)
  statistic           = lookup(var.autoscale, "statistic", "Average")
  datapoints_to_alarm = lookup(var.autoscale, "datapoints_to_alarm", 3)

  dimensions = {
    ClusterName = local.keycloak_ecs_cluster_name
    ServiceName = aws_ecs_service.keycloak-service.name
  }
}

resource "aws_appautoscaling_target" "keycloak-ecs-target" {
  max_capacity       = lookup(var.autoscale, "autoscale_max_capacity", 4)
  min_capacity       = lookup(var.autoscale, "service_desired_count", 2)
  resource_id        = "service/${local.keycloak_ecs_cluster_name}/${aws_ecs_service.keycloak-service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  role_arn           = aws_iam_role.keycloak-ecs-autoscale-role.arn
}

# Set up the memory utilization policy for scale down when the cloudwatch alarm gets triggered.
resource "aws_appautoscaling_policy" "keycloak-policy-scale-down" {
  name               = "keycloak-service-down"
  resource_id        = aws_appautoscaling_target.keycloak-ecs-target.resource_id
  scalable_dimension = aws_appautoscaling_target.keycloak-ecs-target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.keycloak-ecs-target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = var.autoscale["adjustment_type"]
    cooldown                = var.autoscale["cooldown"]
    metric_aggregation_type = lookup(var.autoscale, "aggregation_type", "Average")

    step_adjustment {
      metric_interval_upper_bound = lookup(var.autoscale, "scale_down_interval_lower_bound", 0)
      scaling_adjustment          = var.autoscale["scale_down_adjustment"]
    }
  }
}

# Set up the memory utilization policy for scale up when the cloudwatch alarm gets triggered.
resource "aws_appautoscaling_policy" "keycloak-policy-scale-up" {
  name               = "keycloak-service-up"
  resource_id        = aws_appautoscaling_target.keycloak-ecs-target.resource_id
  scalable_dimension = aws_appautoscaling_target.keycloak-ecs-target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.keycloak-ecs-target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = var.autoscale["adjustment_type"]
    cooldown                = var.autoscale["cooldown"]
    metric_aggregation_type = lookup(var.autoscale, "aggregation_type", "Average")

    step_adjustment {
      metric_interval_lower_bound = lookup(var.autoscale, "scale_up_interval_lower_bound", 1)
      scaling_adjustment          = var.autoscale["scale_up_adjustment"]
    }
  }
}

