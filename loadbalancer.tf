locals {
  # get these values from either input variables, or internal resources if the variables weren't passed
  certificate_arn = var.acm_certificate_arn == null ? join("", aws_acm_certificate.keycloak-certificate.*.arn) : var.acm_certificate_arn
  lb_log_bucket   = var.lb_access_logs_s3_bucket == null ? join("", aws_s3_bucket.keycloak-lb-access-logs.*.id) : var.lb_access_logs_s3_bucket

  admin_paths = [
    "/auth/realms/master/*",
    "/auth/admin/master/console*"
  ]
  # ALB rules can only have 5 items in them, and we also have a host header rule, so limit them to 5 - 1
  admin_cidrs_chunked = var.admin_cidrs == null ? [] : chunklist(var.admin_cidrs, 4)
}

resource "aws_security_group" "keycloak-load-balancer-sg" {
  vpc_id      = var.vpc_id
  name_prefix = "keycloak-${var.environment}-load-balancer-sg"
  description = "Security group for the Keycloak loadbalancer"

  ingress {
    description      = "Allow incoming HTTPS traffic"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = merge(var.tags, {
    Name = "keycloak-${var.environment}-load-balancer-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "keycloak_load_balancer_sg" {
  security_group_id            = aws_security_group.keycloak-load-balancer-sg.id
  description                  = "Allow traffic to Keycloak tasks"
  from_port                    = 8080
  to_port                      = 9090
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.keycloak-sg.id
}

resource "aws_alb" "keycloak-load-balancer" {
  name                       = "keycloak-${var.environment}-alb"
  internal                   = false
  load_balancer_type         = "application"
  subnets                    = var.public_subnets
  security_groups            = [aws_security_group.keycloak-load-balancer-sg.id]
  enable_deletion_protection = !var.is_temporary
  drop_invalid_header_fields = true

  # LB access logs
  access_logs {
    bucket  = local.lb_log_bucket
    prefix  = "keycloak-${var.environment}"
    enabled = var.lb_enable_access_logs
  }

  # checkov:skip=CKV_AWS_150:deletion protection enabled for non-temporary LBs
  # checkov:skip=CKV_AWS_91:access logging is enabled if configured
  # checkov:skip=CKV2_AWS_76:Log4J is the responsibility of the WAF
  # checkov:skip=CKV2_AWS_28:WAF not configured yet:
  # - https://app.asana.com/1/15492006741476/project/1113179098808463/task/1201986044378966?focus=true
  # - https://app.asana.com/1/15492006741476/project/1113179098808463/task/1212505288488894?focus=true
  # - https://app.asana.com/1/15492006741476/project/1113179098808463/task/1201986044378968?focus=true

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
  count        = length(local.admin_cidrs_chunked)
  listener_arn = aws_lb_listener.keycloak-listener.arn
  priority     = 50 + count.index
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.keycloak-target-group.id
  }

  condition {
    host_header {
      values = [local.admin_hostname]
    }
  }
  condition {
    source_ip {
      values = local.admin_cidrs_chunked[count.index]
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
    host_header {
      values = [local.admin_hostname]
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

resource "aws_wafv2_web_acl_association" "waf_web_acl" {
  count        = var.lb_web_acl_arn == null ? 0 : 1
  resource_arn = aws_alb.keycloak-load-balancer.arn
  web_acl_arn  = var.lb_web_acl_arn
}
