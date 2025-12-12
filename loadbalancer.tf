locals {
  # get these values from either input variables, or internal resources if the variables weren't passed
  certificate_arn = var.acm_certificate_arn == null ? join("", aws_acm_certificate.keycloak-certificate.*.arn) : var.acm_certificate_arn
  lb_log_bucket   = var.lb_access_logs_s3_bucket == null ? join("", aws_s3_bucket.keycloak-lb-access-logs.*.id) : var.lb_access_logs_s3_bucket

  admin_paths = [
    "/auth/realms/master/*",
    "/auth/admin/master/console*"
  ]
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
  access_logs {
    bucket  = local.lb_log_bucket
    prefix  = "keycloak-${var.environment}"
    enabled = var.lb_enable_access_logs
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
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "10"
    path                = "/auth/health"
    port                = 9000
    unhealthy_threshold = "3"
  }

  tags = var.tags
}


resource "aws_lb_listener" "keycloak-listener" {
  load_balancer_arn = aws_alb.keycloak-load-balancer.id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.keycloak-target-group.id
  }

  tags = var.tags
}

resource "aws_lb_listener_rule" "forward_admin_from_cidrs" {
  count        = var.admin_cidrs == null ? 0 : 1
  listener_arn = aws_lb_listener.keycloak-listener.arn
  priority     = 50
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.keycloak-target-group.id
  }

  condition {
    path_pattern {
      values = local.admin_paths
    }
    source_ip {
      values = var.admin_cidrs
    }
  }
}

resource "aws_lb_listener_rule" "redirect_admin_from_other_cidrs" {
  count        = var.admin_cidrs == null ? 0 : 1
  listener_arn = aws_lb_listener.keycloak-listener.arn
  priority     = 60

  action {
    type = "redirect"
    redirect {
      host        = "www.mbta.com"
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_302"
      path        = "/"
      query       = ""
    }
  }

  condition {
    path_pattern {
      values = local.admin_paths
    }
  }
}

resource "aws_lb_listener_rule" "redirect_to_mbta_com" {
  listener_arn = aws_lb_listener.keycloak-listener.arn
  priority     = 100
  action {
    type = "redirect"
    redirect {
      host        = "www.mbta.com"
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
      path        = "/"
      query       = ""
    }
  }
  condition {
    path_pattern {
      values = ["/"]
    }
  }

  tags = merge(var.tags, {
    Name = "Redirect-to-MBTA-page"
  })
}
