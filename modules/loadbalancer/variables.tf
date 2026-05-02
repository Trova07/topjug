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
  description = "HTTPS 리스너에 붙일 ACM 인증서 ARN (dns 모듈에서 전달)"
  type        = string
}
