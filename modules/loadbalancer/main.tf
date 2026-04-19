# ── ALB ──────────────────────────────────────────────────

resource "aws_lb" "main" {
  name               = "${var.project}-alb"
  internal           = false # 인터넷 facing
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnets # ALB는 2개 AZ 필요

  tags = { Name = "${var.project}-alb" }
}

# ── Target Group (ECS Task 연결) ──────────────────────────

resource "aws_lb_target_group" "api" {
  name        = "${var.project}-api-tg"
  port        = 3000 # API 서버 포트 (필요 시 변경)
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Fargate는 반드시 ip 타입

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = { Name = "${var.project}-api-tg" }
}

# ── Listener ──────────────────────────────────────────────

# HTTP → 80 포트 리스너 (도메인 연결 후 443 HTTPS 추가 예정)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# HTTPS 리스너는 도메인 + ACM 인증서 발급 후 아래 주석 해제
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
#   certificate_arn   = var.acm_certificate_arn
#
#   default_action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.api.arn
#   }
# }
