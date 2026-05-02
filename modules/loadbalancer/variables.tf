variable "project" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "alb_sg_id" {
  type = string
}

variable "acm_certificate_arn" {
  description = "HTTPS 리스너에 붙일 ACM 인증서 ARN — 비워두면 HTTP만 오픈 (도메인 설정 전 단계)"
  type        = string
  default     = "" # 도메인 준비 전까지는 빈값으로 두면 HTTP만 동작
}
