output "rds_endpoint" {
  value = data.aws_db_instance.database.endpoint
}

output "alb_endpoint" {
  value = data.aws_lb.keycloak-alb-ref.dns_name
}
