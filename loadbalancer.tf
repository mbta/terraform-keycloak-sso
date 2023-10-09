locals {
  # get these values from either input variables, or internal resources if the variables weren't passed
  certificate_arn = var.acm_certificate_arn == null ? join("", aws_acm_certificate.keycloak-certificate.*.arn) : var.acm_certificate_arn
  lb_log_bucket   = var.lb_access_logs_s3_bucket == null ? join("", aws_s3_bucket.keycloak-lb-access-logs.*.id) : var.lb_access_logs_s3_bucket
}

resource "aws_security_group" "keycloak-load-balancer-sg" {
  vpc_id = var.vpc_id
  name   = "keycloak-${var.environment}-load-balancer-sg"

  ingress {
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
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

resource "aws_alb" "keycloak-load-balancer" {
  name               = "keycloak-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [aws_security_group.keycloak-load-balancer-sg.id]

  # LB access logs
  dynamic "access_logs" {
    # only include this block if var.lb_enable_access_logs is true
    for_each = var.lb_enable_access_logs == true ? toset([1]) : toset([])

    content {
      bucket  = local.lb_log_bucket
      prefix  = "keycloak-${var.environment}"
      enabled = var.lb_enable_access_logs
    }
  }

  tags = var.tags
}

resource "aws_lb_target_group" "keycloak-target-group" {
  name        = "keycloak-${var.environment}-target-group"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  stickiness {
    enabled = true
    type    = "lb_cookie"
  }

  health_check {
    healthy_threshold   = "3"
    interval            = "300"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/auth/"
    unhealthy_threshold = "2"
  }

  tags = var.tags
}


resource "aws_lb_listener" "keycloak-listener" {
  load_balancer_arn = aws_alb.keycloak-load-balancer.id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  certificate_arn   = local.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.keycloak-target-group.id
  }
}
