variable "project" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "ecs_sg_id" {
  type = string
}

variable "alb_target_group_arn" {
  type = string
}

variable "ecr_api_url" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type    = number
  default = 5432
}

variable "db_name" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "api_cpu" {
  type = number
}

variable "api_memory" {
  type = number
}

variable "api_desired_count" {
  type = number
}

variable "ec2_instance_type" {
  description = "ECS EC2 인스턴스 타입 — t4g(ARM Graviton2) 계열 사용"
  type        = string
  default     = "t4g.small" # 2 vCPU / 2 GiB — API 512MB + Redis 256MB 적정
}

variable "uploads_bucket_arn" {
  description = "유저 업로드 S3 버킷 ARN (API Task IAM 정책에 사용)"
  type        = string
}
