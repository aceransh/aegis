resource "aws_lb" "broker" {
  name               = "prod-broker-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "broker" {
  name        = "prod-broker-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path     = "/health"
    protocol = "HTTP"
  }
}

# Plain HTTP — a real production listener would terminate TLS via an ACM
# cert, but that needs a real domain for validation, which Day 5 already
# ruled out owning. Same "explicit placeholder, not real" treatment Day 2
# gave the image URI and DB_DSN before they had real values.
resource "aws_lb_listener" "broker" {
  load_balancer_arn = aws_lb.broker.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.broker.arn
  }
}
