locals {
  # get this value from either input variables, or internal resources if the variables weren't passed
  db_subnet_group = var.database_subnet_group == null ? join("", aws_db_subnet_group.keycloak-database-subnet.*.name) : var.database_subnet_group
}

resource "random_password" "database-password" {
  length  = 32
  special = false
}

resource "aws_db_subnet_group" "keycloak-database-subnet" {
  # only create this resource if database_subnet_group is null
  count = var.database_subnet_group == null ? 1 : 0

  name       = "keycloak-${var.environment}-database-subnet"
  subnet_ids = var.private_subnets

  tags = var.tags
}

resource "aws_security_group" "database-sg" {
  vpc_id = var.vpc_id
  name   = "keycloak-${var.environment}-database-sg"
  ingress {
    description     = "MariaDB port"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.keycloak-sg.id]
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

resource "aws_db_parameter_group" "rds-mariadb-pg" {
  name   = "rds-keycloak-${var.environment}-mariadb-pg"
  family = "mariadb10.5"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }

  tags = var.tags
}

resource "aws_db_option_group" "rds-mariadb-og" {
  name                     = "rds-keycloak-${var.environment}-mariadb-og"
  option_group_description = "Terraform Option Group Maria DB"
  engine_name              = "mariadb"
  major_engine_version     = "10.5"

  option {
    option_name = "MARIADB_AUDIT_PLUGIN"

    /*option_settings {
      name  = "SERVER_AUDIT_LOGGING"
      value = "ON"
    }*/
  }

  tags = var.tags
}

resource "aws_db_instance" "keycloak-database-engine" {
  name                   = var.db_name
  identifier             = "keycloak-${var.environment}-database-engine"
  allocated_storage      = 20
  max_allocated_storage  = 100
  engine                 = "mariadb"
  engine_version         = "10.5.12"
  instance_class         = "db.t2.micro"
  db_subnet_group_name   = local.db_subnet_group
  multi_az               = true
  username               = var.db_username
  parameter_group_name   = "rds-keycloak-${var.environment}-mariadb-pg"
  option_group_name      = "rds-keycloak-${var.environment}-mariadb-og"
  vpc_security_group_ids = [aws_security_group.database-sg.id]
  skip_final_snapshot    = true
  monitoring_interval    = 15
  monitoring_role_arn    = aws_iam_role.keycloak-db-monitoring-role.arn

  # this value leaks into state and thus should be changed on creation.
  # any changes are ignored by the lifecycle policy below.
  password = random_password.database-password.result

  lifecycle {
    ignore_changes = [
      password,
    ]
  }

  tags = var.tags

  depends_on = [aws_db_option_group.rds-mariadb-og, aws_db_parameter_group.rds-mariadb-pg, aws_iam_role.keycloak-db-monitoring-role]
}
