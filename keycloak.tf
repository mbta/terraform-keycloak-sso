locals {
  # get these values from either input variables, or internal resources if the variables weren't passed
  keycloak_image_url        = var.ecr_keycloak_image_url == null ? join("", aws_ecr_repository.keycloak-image-repository.*.repository_url) : var.ecr_keycloak_image_url
  keycloak_ecs_cluster_name = var.ecs_cluster_name == null ? "keycloak-${var.environment}-cluster" : var.ecs_cluster_name
  keycloak_ecs_cluster_arn  = var.ecs_cluster_name == null ? join("", aws_ecs_cluster.keycloak-cluster.*.arn) : join("", data.aws_ecs_cluster.keycloak-cluster.*.arn)
}

data "aws_ecs_cluster" "keycloak-cluster" {
  count = var.ecs_cluster_name != null ? 1 : 0

  cluster_name = var.ecs_cluster_name
}

resource "aws_ecs_cluster" "keycloak-cluster" {
  # only create this resource if ecs_cluster_arn is null
  count = var.ecs_cluster_name == null ? 1 : 0

  name = local.keycloak_ecs_cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_security_group" "keycloak-sg" {
  vpc_id = var.vpc_id
  name   = "keycloak-${var.environment}-sg"

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.keycloak-load-balancer-sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = var.tags
}

resource "aws_ecs_task_definition" "keycloak-ecs-taskdef" {
  family = "keycloak-${var.environment}-template"

  container_definitions = <<DEFINITION
  [
    {
      "name": "keycloak-${var.environment}",
      "image": "${local.keycloak_image_url}:${var.ecr_keycloak_image_tag}",
      "entryPoint": [],
      "environment": [
        {"name":"KEYCLOAK_USER", "value":"${var.kc_username}"},
        {"name":"PROXY_ADDRESS_FORWARDING", "value":"true"},
        {"name":"KEYCLOAK_LOGLEVEL", "value":"INFO"},
        {"name":"ROOT_LOGLEVEL", "value":"INFO"},
        {"name":"DB_VENDOR", "value":"mariadb"},
        {"name":"DB_ADDR", "value":"${aws_db_instance.keycloak-database-engine.endpoint}"},
        {"name":"DB_DATABASE", "value":"${var.db_name}"},
        {"name":"DB_USER", "value":"${var.db_username}"},
        {"name":"JDBC_PARAMS", "value":"autoReconnect=true"},
        {"name":"JAVA_OPTS_APPEND", "value":"-Xmx1500m -DawsEnv=${var.environment}"},
        {"name":"JGROUPS_DISCOVERY_PROTOCOL", "value":"JDBC_PING"},
        {"name":"JGROUPS_DISCOVERY_PROPERTIES", "value":"datasource_jndi_name=java:jboss/datasources/KeycloakDS,remove_old_coords_on_view_change=true"},
        {"name":"CACHE_OWNERS_COUNT", "value":"2"},
        {"name":"CACHE_OWNERS_AUTH_SESSIONS_COUNT", "value":"2"}
      ],
      "secrets": [
        {"name":"KEYCLOAK_PASSWORD", "valueFrom":"${aws_secretsmanager_secret.keycloak-admin-password.arn}"},
        {"name":"DB_PASSWORD", "valueFrom":"${aws_secretsmanager_secret.keycloak-database-password.arn}"}
      ],
      "essential": true,
      "logConfiguration": ${local.log_configuration},
      "portMappings": [
        {
          "containerPort": 8080,
          "hostPort": 8080
        },
        {
          "containerPort": 7600,
          "hostPort": 7600
        }
      ],
      "cpu": 512,
      "memory": 2048,
      "networkMode": "awsvpc"
    }
  ]
  DEFINITION

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "2048"
  cpu                      = "512"
  execution_role_arn       = aws_iam_role.keycloak-ecs-execution-task-role.arn
  task_role_arn            = aws_iam_role.keycloak-ecs-execution-task-role.arn

  tags = var.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_ecs_service" "keycloak-service" {
  name                 = "keycloak-${var.environment}"
  cluster              = local.keycloak_ecs_cluster_arn
  task_definition      = aws_ecs_task_definition.keycloak-ecs-taskdef.arn
  launch_type          = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count        = 2
  force_new_deployment = true

  network_configuration {
    subnets          = var.private_subnets
    assign_public_ip = false
    security_groups = [
      aws_security_group.keycloak-sg.id,
      aws_security_group.keycloak-load-balancer-sg.id
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.keycloak-target-group.arn
    container_name   = "keycloak-${var.environment}"
    container_port   = 8080
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      desired_count,
      task_definition,
    ]
  }

  depends_on = [aws_lb_listener.keycloak-listener, aws_iam_role.keycloak-ecs-execution-task-role, aws_db_instance.keycloak-database-engine]
}

