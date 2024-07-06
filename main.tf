terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_security_group" "nice_lb" {
  name = "nice lb sg"
  description = "allow traffic on port 80"

  dynamic "ingress" {
    for_each = var.security_group_ingress
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = var.security_group_egress
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  vpc_id = aws_default_vpc.default.id
}

resource "aws_security_group" "nice_instance_sg" {
  name = "nice ec2 instance sg"
  description = "allow traffic from nice LB"

  dynamic "ingress" {
    for_each = var.security_group_ingress
    content {
      from_port       = ingress.value.from_port
      to_port         = ingress.value.to_port
      protocol        = ingress.value.protocol
      security_groups = [aws_security_group.nice_lb.id]

    }
  }

  dynamic "egress" {
    for_each = var.security_group_egress
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  vpc_id = aws_default_vpc.default.id
}

resource "aws_launch_template" "nice_launch_template" {
  name          = "nice-launch-tempalte"
  image_id      = data.aws_ami.latest_ami.id
  instance_type = var.instance_type

  network_interfaces {
    security_groups = [aws_security_group.nice_instance_sg.id]
    associate_public_ip_address = true
  }

  user_data = base64encode(data.local_file.user_data.content)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_target_group" "nice_target_group" {
  name        = "nice-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_default_vpc.default.id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_autoscaling_group" "nice_asg" {
for_each = var.asg_config
  name                 = each.value.name
  min_size             = each.value.min_size
  max_size             = each.value.max_size
  desired_capacity     = each.value.desired_capacity
  availability_zones   = each.value.azs
  
  launch_template {
    id      = aws_launch_template.nice_launch_template.id
    version = "$Latest"
  } 

  tag {
    key                 = "Name"
    value               = "nice-instance"
    propagate_at_launch = true
  }
}

resource "aws_lb" "nice_alb" {
  name               = "nice"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.nice_lb.id]
  subnets            = [data.aws_subnet.default_subnet_a.id, data.aws_subnet.default_subnet_b.id]
}

resource "aws_lb_listener" "nice_alb_listener" {
  load_balancer_arn = aws_lb.nice_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nice_target_group.arn
  }
}

resource "aws_autoscaling_attachment" "nice_autoscaling_attach" {
for_each = aws_autoscaling_group.nice_asg
  autoscaling_group_name = each.value.id
  lb_target_group_arn   = aws_lb_target_group.nice_target_group.arn
}