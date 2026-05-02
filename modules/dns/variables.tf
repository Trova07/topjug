variable "project" {
  type = string
}

variable "domain_name" {
  description = "Route53에 등록할 루트 도메인 (예: topjug.kr)"
  type        = string
}

variable "alb_dns_name" {
  description = "A 레코드 alias 대상 — ALB의 DNS 이름"
  type        = string
}

variable "alb_zone_id" {
  description = "A 레코드 alias 대상 — ALB의 hosted zone ID"
  type        = string
}
