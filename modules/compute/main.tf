# ── ECS 클러스터 ──────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # CloudWatch Container Insights 활성화
  }

  tags = { Name = "${var.project}-cluster" }
}

# ── CloudWatch 로그 그룹 ───────────────────────────────────

resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.project}/api"
  retention_in_days = 30

  tags = { Name = "${var.project}-api-logs" }
}

resource "aws_cloudwatch_log_group" "redis" {
  name              = "/ecs/${var.project}/redis"
  retention_in_days = 14

  tags = { Name = "${var.project}-redis-logs" }
}

# ── IAM: ECS Task Execution Role ─────────────────────────
# Fargate가 ECR pull, CloudWatch 로그 쓰기 등을 하기 위한 권한

resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ── ECS Service Discovery (Cloud Map) ────────────────────
# Redis Task의 내부 DNS 주소를 API Task에서 redis.topjug.local 로 접근

resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "${var.project}.local"
  vpc  = var.vpc_id

  tags = { Name = "${var.project}-service-discovery" }
}

resource "aws_service_discovery_service" "redis" {
  name = "redis"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# ── Redis Task Definition ─────────────────────────────────

resource "aws_ecs_task_definition" "redis" {
  family                   = "${var.project}-redis"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "redis"
      image     = "redis:7-alpine"
      essential = true

      portMappings = [{ containerPort = 6379, protocol = "tcp" }]

      # 재시작 시 캐시 소멸 허용 (초기 전략)
      # 영속성 필요 시 EFS 마운트 또는 ElastiCache 전환 검토

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.redis.name
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "redis"
        }
      }
    }
  ])

  tags = { Name = "${var.project}-redis-task" }
}

resource "aws_ecs_service" "redis" {
  name            = "${var.project}-redis"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.redis.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.public_subnets[0]] # Redis는 단일 서브넷
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = aws_service_discovery_service.redis.arn
  }

  tags = { Name = "${var.project}-redis-service" }
}

# ── API Task Definition ───────────────────────────────────

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.api_cpu
  memory                   = var.api_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${var.ecr_api_url}:latest"
      essential = true

      portMappings = [{ containerPort = 3000, protocol = "tcp" }]

      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "3000" },
        { name = "DB_HOST", value = var.db_host },
        { name = "DB_PORT", value = tostring(var.db_port) },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_USER", value = var.db_username },
        # Redis: Service Discovery로 접근 (redis.topjug.local:6379)
        { name = "REDIS_HOST", value = "redis.${var.project}.local" },
        { name = "REDIS_PORT", value = "6379" },
      ]

      secrets = [
        # 민감 정보는 Secrets Manager 또는 SSM Parameter Store 권장
        # 현재는 환경변수로 주입 (추후 개선)
        { name = "DB_PASSWORD", valueFrom = "/topjug/db_password" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.api.name
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "api"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = { Name = "${var.project}-api-task" }
}

resource "aws_ecs_service" "api" {
  name            = "${var.project}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnets
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = true # NAT GW 없이 ECR pull을 위해 필요
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "api"
    container_port   = 3000
  }

  # 새 Task 배포 시 기존 Task 유지 전략 (무중단 배포)
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  depends_on = [aws_ecs_service.redis]

  tags = { Name = "${var.project}-api-service" }
}

# ── SSM Parameter Store (DB 비밀번호) ────────────────────

resource "aws_ssm_parameter" "db_password" {
  name  = "/topjug/db_password"
  type  = "SecureString"
  value = var.db_password

  tags = { Name = "${var.project}-db-password" }
}

# Task Execution Role에 SSM 읽기 권한 추가
resource "aws_iam_role_policy" "ssm_read" {
  name = "${var.project}-ssm-read"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameters", "ssm:GetParameter"]
      Resource = "arn:aws:ssm:ap-northeast-2:*:parameter/topjug/*"
    }]
  })
}
