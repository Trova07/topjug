# ── ECS 클러스터 ──────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "${var.project}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
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
# ECR pull, CloudWatch 로그 쓰기 권한

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

# ── IAM: EC2 Instance Role ────────────────────────────────
# EC2가 ECS 클러스터에 등록되기 위한 권한 (Fargate엔 없던 것)

resource "aws_iam_role" "ecs_instance" {
  name = "${var.project}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${var.project}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name
}

# ── ECS 최적화 AMI (최신 버전 자동 조회) ──────────────────

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# ── Launch Template ───────────────────────────────────────

resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project}-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.ec2_instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  network_interfaces {
    associate_public_ip_address = true # NAT GW 없이 ECR pull 필요
    security_groups             = [var.ecs_sg_id]
  }

  # EC2 부팅 시 ECS 클러스터에 자동 등록
  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
    echo ECS_ENABLE_AWSLOGS_EXECUTIONROLE_OVERRIDE=true >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project}-ecs-instance" }
  }
}

# ── Auto Scaling Group ────────────────────────────────────

resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project}-ecs-asg"
  vpc_zone_identifier = var.public_subnets
  min_size            = 1
  max_size            = 2 # 여유분 1대 (비용 최소화)
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.project}-ecs-instance"
    propagate_at_launch = true
  }

  # 인스턴스 교체 시 새 인스턴스 먼저 올리고 기존 종료
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 100
    }
  }
}

# ── ECS Capacity Provider ─────────────────────────────────
# ASG와 ECS 클러스터를 연결

resource "aws_ecs_capacity_provider" "main" {
  name = "${var.project}-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 80 # EC2 사용률 80% 기준으로 스케일링 판단
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
  }
}

# ── ECS Service Discovery (Cloud Map) ────────────────────
# API → Redis 내부 DNS 접근: redis.topjug.local:6379

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
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "redis"
      image     = "redis:7-alpine"
      essential = true
      memory    = 256 # 컨테이너 레벨 메모리 제한

      portMappings = [{ containerPort = 6379, protocol = "tcp" }]

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

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
  }

  network_configuration {
    subnets         = [var.public_subnets[0]]
    security_groups = [var.ecs_sg_id]
    # assign_public_ip 제거 — EC2 인스턴스가 public IP 보유
  }

  service_registries {
    registry_arn = aws_service_discovery_service.redis.arn
  }

  depends_on = [aws_ecs_cluster_capacity_providers.main]

  tags = { Name = "${var.project}-redis-service" }
}

# ── API Task Definition ───────────────────────────────────

resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "${var.ecr_api_url}:latest"
      essential = true
      memory    = 512 # 컨테이너 레벨 메모리 제한

      portMappings = [{ containerPort = 3000, protocol = "tcp" }]

      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "3000" },
        { name = "DB_HOST", value = var.db_host },
        { name = "DB_PORT", value = tostring(var.db_port) },
        { name = "DB_NAME", value = var.db_name },
        { name = "DB_USER", value = var.db_username },
        { name = "REDIS_HOST", value = "redis.${var.project}.local" },
        { name = "REDIS_PORT", value = "6379" },
      ]

      secrets = [
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

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
  }

  network_configuration {
    subnets         = var.public_subnets
    security_groups = [var.ecs_sg_id]
  }

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "api"
    container_port   = 3000
  }

  deployment_minimum_healthy_percent = 50  # EC2 1대 환경에서 100%면 배포 불가
  deployment_maximum_percent         = 200

  depends_on = [
    aws_ecs_service.redis,
    aws_ecs_cluster_capacity_providers.main
  ]

  tags = { Name = "${var.project}-api-service" }
}

# ── SSM Parameter Store (DB 비밀번호) ────────────────────

resource "aws_ssm_parameter" "db_password" {
  name  = "/topjug/db_password"
  type  = "SecureString"
  value = var.db_password

  tags = { Name = "${var.project}-db-password" }
}

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
