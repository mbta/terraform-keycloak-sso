locals {
  keycloak_image_url       = var.ecr_keycloak_image_url == null ? aws_ecr_repository.keycloak-image-repository.*.repository_url : var.ecr_keycloak_image_url
  keycloak_ecs_cluster_arn = var.ecs_cluster_arn == null ? aws_ecs_cluster.keycloak-cluster.*.arn : var.ecs_cluster_arn
}

resource "aws_ecs_cluster" "keycloak-cluster" {
  count = var.ecs_cluster_arn == null ? 1 : 0

  name = "keycloak-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    project = "MBTA-Keycloak"
    Name    = "Keycloak ESC cluster"
  }
}

resource "aws_cloudwatch_log_group" "keycloak-log-group" {
  name              = "keycloak-${var.environment}-logs"
  retention_in_days = 30
  tags = {
    project = "MBTA-Keycloak"
    Name    = "Keycloak CloudWatch"
  }
}


resource "aws_security_group" "keycloak-sg" {
  vpc_id = var.vpc_id
  name   = "keycloak-${var.environment}-sg"

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.load-balancer-sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    project = "MBTA-Keycloak"
    Name    = "Keycloak-service-sg"
  }
}

resource "aws_ecs_task_definition" "aws-ecs-keycloak-taskdef" {
  family = "keycloak-${var.environment}-task"

  container_definitions = <<DEFINITION
  [
    {
      "name": "keycloak-${var.environment}",
      "image": "${local.keycloak_image_url}:latest",
      "entryPoint": [],
      "environment": [
        {"name":"KEYCLOAK_USER", "value":"${var.kc_username}"},
        {"name":"PROXY_ADDRESS_FORWARDING", "value":"true"},
        {"name":"KEYCLOAK_LOGLEVEL", "value":"INFO"},
        {"name":"ROOT_LOGLEVEL", "value":"INFO"},
        {"name":"DB_VENDOR", "value":"mariadb"},
        {"name":"DB_ADDR", "value":"${data.aws_db_instance.database.endpoint}"},
        {"name":"DB_DATABASE", "value":"${var.db_name}"},
        {"name":"DB_USER", "value":"${var.db_username}"},
        {"name":"JDBC_PARAMS", "value":"autoReconnect=true"},
        {"name":"JAVA_OPTS_APPEND", "value":"-Xmx1500m"},
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
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "${aws_cloudwatch_log_group.keycloak-log-group.id}",
          "awslogs-region": "${var.aws_region}",
          "awslogs-stream-prefix": "log"
        }
      },
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
  execution_role_arn       = aws_iam_role.ecs-execution-task-role.arn
  task_role_arn            = aws_iam_role.ecs-execution-task-role.arn

  tags = {
    project = "MBTA-Keycloak"
    Name    = "keycloak-ecs-taskdef"
  }
}

data "aws_ecs_task_definition" "main" {
  task_definition = aws_ecs_task_definition.aws-ecs-keycloak-taskdef.family
}


resource "aws_ecs_service" "keycloak-service" {
  name                 = "keycloak-${var.environment}-service"
  cluster              = local.keycloak_ecs_cluster_arn
  task_definition      = "${aws_ecs_task_definition.aws-ecs-keycloak-taskdef.family}:${max(aws_ecs_task_definition.aws-ecs-keycloak-taskdef.revision, data.aws_ecs_task_definition.main.revision)}"
  launch_type          = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count        = 2
  force_new_deployment = true

  network_configuration {
    subnets          = var.private_subnets
    assign_public_ip = false
    security_groups = [
      aws_security_group.keycloak-sg.id,
      aws_security_group.load-balancer-sg.id
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target-group.arn
    container_name   = "keycloak-${var.environment}"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.listener, aws_iam_role.ecs-execution-task-role, aws_db_instance.keycloak-database-engine]
}

