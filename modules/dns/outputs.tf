output "acm_certificate_arn" {
  description = "ALB HTTPS 리스너에 붙일 ACM 인증서 ARN"
  value       = aws_acm_certificate_validation.main.certificate_arn
}

output "zone_id" {
  description = "Route53 Hosted Zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "nameservers" {
  description = "도메인 등록업체에 설정해야 할 NS 레코드 값 (4개)"
  value       = aws_route53_zone.main.name_servers
}
