output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "alb_dns_name" {
  description = "ALB DNS 주소 (API 엔드포인트)"
  value       = module.loadbalancer.alb_dns_name
}

output "cloudfront_domain" {
  description = "CloudFront 도메인 (프론트엔드 접속 주소)"
  value       = module.cdn.cloudfront_domain
}

output "s3_bucket_name" {
  description = "프론트엔드 S3 버킷 이름"
  value       = module.storage.bucket_id
}

output "ecr_api_url" {
  description = "API 서버 ECR 저장소 URL (docker push 시 사용)"
  value       = module.ecr.api_repository_url
}

output "db_endpoint" {
  description = "RDS 엔드포인트"
  value       = module.database.db_endpoint
  sensitive   = true
}

output "ecs_cluster_name" {
  description = "ECS 클러스터 이름"
  value       = module.compute.ecs_cluster_name
}

output "uploads_bucket_name" {
  description = "유저 업로드 S3 버킷 이름 (프로필 사진, 암장 이미지)"
  value       = module.storage.uploads_bucket_name
}

# ── DNS ──────────────────────────────────────────────────

output "route53_nameservers" {
  description = <<-EOT
    Route53 Hosted Zone의 NS 레코드값 (4개).
    terraform apply 완료 후 이 값을 도메인 등록업체(가비아, 후이즈 등)의
    네임서버 항목에 입력해야 ACM 인증서 DNS 검증이 완료됩니다.
  EOT
  value       = module.dns.nameservers
}

output "acm_certificate_arn" {
  description = "ALB에 연결된 ACM 인증서 ARN"
  value       = module.dns.acm_certificate_arn
}
