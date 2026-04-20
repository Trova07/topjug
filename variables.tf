variable "project" {
  description = "프로젝트 이름 (리소스 네이밍에 사용)"
  type        = string
  default     = "topjug"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2" # 서울
}

# ── 네트워크 ─────────────────────────────────────────────

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_list" {
  description = "사용할 가용 영역 목록 (ALB는 최소 2개 AZ 필요)"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

# ── 데이터베이스 ─────────────────────────────────────────

variable "db_name" {
  description = "RDS 데이터베이스 이름"
  type        = string
  default     = "topjug"
}

variable "db_username" {
  description = "RDS 마스터 유저명"
  type        = string
  default     = "topjug_admin"
}

variable "db_password" {
  description = "RDS 마스터 비밀번호 (tfvars에서 주입, 절대 하드코딩 금지)"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS 인스턴스 사양 (수직확장 시 여기만 변경)"
  type        = string
  default     = "db.t4g.micro"
}

# ── ECS API 서버 ─────────────────────────────────────────

variable "api_cpu" {
  description = "API Task CPU 유닛 (1024 = 1 vCPU)"
  type        = number
  default     = 256
}

variable "api_memory" {
  description = "API Task 메모리 (MiB)"
  type        = number
  default     = 512
}

variable "api_desired_count" {
  description = "API Task 실행 개수"
  type        = number
  default     = 1
}

variable "ec2_instance_type" {
  description = "ECS EC2 인스턴스 타입 (API 512MB + Redis 256MB 기준 t3.small 적정)"
  type        = string
  default     = "t3.small"
}
