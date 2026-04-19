output "cloudfront_domain" {
  value = aws_cloudfront_distribution.main.domain_name
}

output "cloudfront_distribution_id" {
  description = "프론트엔드 배포 후 캐시 무효화 시 사용"
  value       = aws_cloudfront_distribution.main.id
}
