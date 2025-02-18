locals {
  # get these values from either input variables, or internal resources if the variables weren't passed
  keycloak_image_url        = var.ecr_keycloak_image_url == null ? join("", aws_ecr_repository.keycloak-image-repository.*.repository_url) : var.ecr_keycloak_image_url
  keycloak_ecs_cluster_name = var.ecs_cluster_name == null ? "keycloak-${var.environment}-cluster" : var.ecs_cluster_name
  keycloak_ecs_cluster_arn  = var.ecs_cluster_name == null ? join("", aws_ecs_cluster.keycloak-cluster.*.arn) : join("", data.aws_ecs_cluster.keycloak-cluster.*.arn)
  keycloak_task_cpu         = 1024
  keycloak_task_memory      = 4096
  keycloak_java_memory      = local.keycloak_task_memory - 500
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
        {"name":"KEYCLOAK_ADMIN", "value":"${var.kc_username}"},
        {"name":"KC_DB", "value":"mariadb"},
        {"name":"KC_DB_URL_HOST", "value":"${aws_db_instance.keycloak-database-engine.endpoint}"},
        {"name":"KC_DB_URL_DATABASE", "value":"${var.db_name}"},
        {"name":"KC_DB_URL_PROPERTIES", "value":"?autoReconnect=true"},
        {"name":"KC_DB_USERNAME", "value":"${var.db_username}"},
        {"name":"KC_HTTP_RELATIVE_PATH", "value":"/auth"},
        {"name":"KC_HOSTNAME_STRICT", "value":"false"},
        {"name":"KC_HTTP_ENABLED", "value":"true"},
        {"name":"KC_LOG_LEVEL", "value":"INFO,cz.integsoft:DEBUG,org.infinispan:DEBUG,org.jgroups:DEBUG"},
        {"name":"KC_PROXY", "value":"edge"},
        {"name":"KC_HEALTH_ENABLED", "value":"true"},
        {"name":"JAVA_OPTS_APPEND", "value":"-Xmx${local.keycloak_java_memory}m -DawsRegion=${var.aws_region} -DawsJmsQueues=${var.aws_jms_queues}"},
        {"name":"KC_PROXY_HEADERS", "value":"xforwarded"}
      ],
      "secrets": [
        {"name":"KEYCLOAK_ADMIN_PASSWORD", "valueFrom":"${aws_secretsmanager_secret.keycloak-admin-password.arn}"},
        {"name":"KC_DB_PASSWORD", "valueFrom":"${aws_secretsmanager_secret.keycloak-database-password.arn}"}
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
        },
        {
          "containerPort": 9000,
          "hostPort": 9000
        }
      ],
      "cpu": ${local.keycloak_task_cpu},
      "memory": ${local.keycloak_task_memory},
      "networkMode": "awsvpc"
    }
  ]
  DEFINITION

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = local.keycloak_task_memory
  cpu                      = local.keycloak_task_cpu
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

  tags = var.tags

  depends_on = [aws_lb_listener.keycloak-listener, aws_iam_role.keycloak-ecs-execution-task-role, aws_db_instance.keycloak-database-engine]
}

