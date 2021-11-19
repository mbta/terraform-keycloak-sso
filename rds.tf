resource "aws_db_subnet_group" "keycloak-database-subnet" {
  name       = "keycloak-database-subnet"
  subnet_ids = aws_subnet.private.*.id

  tags = {
    Name     = "Keycloak Database subnet"
    project  = "MBTA-Keycloak"
  }
}

resource "aws_security_group" "database-sg" {
  vpc_id = aws_vpc.keycloak-vpc.id
  name   = "database-sg"
  ingress {
    description     = "MariaDB port"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks      = [aws_vpc.keycloak-vpc.cidr_block]
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
    Name        = "Database-sg"
  }
}

resource "aws_db_parameter_group" "rds-mariadb-pg" {
  name   = "rds-mariadb-pg"
  family = "mariadb10.5"

  parameter {
    name  = "character_set_server"
    value = "utf8"
  }

  parameter {
    name  = "character_set_client"
    value = "utf8"
  }
  
  tags = {
    project = "MBTA-Keycloak"
    Name    = "Database-pg"
  }
}

resource "aws_db_option_group" "rds-mariadb-og" {
  name                     = "rds-mariadb-og"
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
  
  tags = {
    project = "MBTA-Keycloak"
    Name    = "Database-pg"
  }
}

resource "aws_db_instance" "keycloak-database-engine" {
  name                                  = "${var.db_name}"
  identifier                            = "keycloak-database-engine"
  allocated_storage                     = 20
  max_allocated_storage                 = 100
  engine                                = "mariadb"
  engine_version                        = "10.5.12"
  instance_class                        = "db.t2.micro"
  db_subnet_group_name                  = "${aws_db_subnet_group.keycloak-database-subnet.name}"
  multi_az                              = true
  username                              = "${var.db_username}"
  password                              = "${var.db_password}"
  parameter_group_name                  = "rds-mariadb-pg"
  option_group_name                     = "rds-mariadb-og"
  vpc_security_group_ids                = [aws_security_group.database-sg.id]
  skip_final_snapshot                   = true
  monitoring_interval                   = 15
  monitoring_role_arn                   = aws_iam_role.keycloak-db-monitoring-role.arn

  tags = {
    project = "MBTA-Keycloak"
    Name    = "Keycloak Database"
  }
  
  depends_on = [aws_db_option_group.rds-mariadb-og,aws_db_parameter_group.rds-mariadb-pg,aws_iam_role.keycloak-db-monitoring-role]
}

/*resource "aws_db_snapshot" "keycloak-db-snapshots" {
  db_instance_identifier = aws_db_instance.keycloak-database-engine.id
  db_snapshot_identifier = "keycloak-db-snapshot"
}*/

data "aws_db_instance" "database" {
  db_instance_identifier = "keycloak-database-engine"
  
  depends_on = [aws_db_instance.keycloak-database-engine]
}

