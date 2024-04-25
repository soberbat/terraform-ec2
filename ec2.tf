resource "aws_launch_configuration" "testServer" {
  image_id        = "ami-023adaba598e661ac"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  lifecycle {
    create_before_destroy = true
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y &&
                sudo apt install -y nginx
                sudo service nginx start
            EOF
}

resource "aws_autoscaling_group" "asgroup" {
  launch_configuration = aws_launch_configuration.testServer.name
  vpc_zone_identifier  = data.aws_subnets.default-subnets.ids

  target_group_arns = [aws_lb_target_group.tg-alb.arn]
  health_check_type = "ELB"

  max_size = 10
  min_size = 2

  tag {
    key                 = "Auto Scaling Group"
    value               = "web"
    propagate_at_launch = true
  }
}

resource "aws_security_group" "instance" {
  name = "web"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "load-balancer" {
  name               = "web-server"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default-subnets.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_security_group" "alb" {
  name = "alb-web"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "tg-alb" {
  name     = "test"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default-vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_alb_listener" "listener" {
  load_balancer_arn = aws_alb.load-balancer.arn
  port              = var.server_port
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"


    fixed_response {
      content_type = "text/plain"
      message_body = "404: Page Not Found"
      status_code  = 400
    }
  }
}

resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_alb_listener.listener.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-alb.arn
  }
}
