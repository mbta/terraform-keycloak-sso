resource "aws_security_group" "load-balancer-sg" {
  vpc_id = aws_vpc.keycloak-vpc.id
  name   = "load-balancer-sg"

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
  name               = "keycloak-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public.*.id
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
  name        = "keycloak-target-group"
  port        = 8080
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.keycloak-vpc.id

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
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.mbta.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target-group.id
  }
}

resource "aws_lb_listener_certificate" "keycloak-lb-certificate" {
  listener_arn    = aws_lb_listener.listener.arn
  certificate_arn = aws_acm_certificate.keycloak-certificate.arn
}

data "aws_lb" "keycloak-alb-ref" {
  arn  = aws_alb.application-load-balancer.arn
}

