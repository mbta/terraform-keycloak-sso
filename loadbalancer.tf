locals {
  certificate_arn = var.acm_certificate_arn == null ? aws_acm_certificate.keycloak-certificate.*.arn : var.acm_certificate_arn
}

resource "aws_security_group" "load-balancer-sg" {
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

  tags = {
    project     = "MBTA-Keycloak"
    Name        = "Keycloak-alb-sg"
  }
}

resource "aws_alb" "application-load-balancer" {
  name               = "keycloak-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [aws_security_group.load-balancer-sg.id]

  # LB access logs
  access_logs {
    bucket  = aws_s3_bucket.mbta-lb-access-logs.bucket
    prefix  = "lb-keycloak"
    enabled = true
  }

  tags = {
    project     = "MBTA-Keycloak"
    Name        = "Keycloak-alb"
  }

  depends_on = [aws_s3_bucket.mbta-lb-access-logs]
}

resource "aws_lb_target_group" "target-group" {
  name        = "keycloak-${var.environment}-target-group"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  stickiness {
    enabled = true
    type     = "lb_cookie"
  }

  health_check {
    healthy_threshold   = "3"
    interval            = "300"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = "/"
    unhealthy_threshold = "2"
  }

  tags = {
    project     = "MBTA-Keycloak"
    Name        = "Keycloak-lb-tg"
  }
}


resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.application-load-balancer.id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-FS-1-2-Res-2020-10"
  certificate_arn   = local.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group.id
  }
}

data "aws_lb" "keycloak-alb-ref" {
  arn  = aws_alb.application-load-balancer.arn
}

