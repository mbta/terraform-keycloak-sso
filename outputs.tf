output "rds_endpoint" {
  value = aws_db_instance.keycloak-database-engine.endpoint
}

output "alb_endpoint" {
  value = aws_alb.keycloak-load-balancer.dns_name
}

output "alb_zone_id" {
  value = aws_alb.keycloak-load-balancer.zone_id
}

output "sqs_queues" {
  value = aws_sqs_queue.keycloak_to_app_user_updates
}

output "admin_password_secret_id" {
  value = aws_secretsmanager_secret.keycloak-admin-password.id
}
