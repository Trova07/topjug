output "bucket_id" {
  value = aws_s3_bucket.frontend.id
}

output "bucket_arn" {
  value = aws_s3_bucket.frontend.arn
}

output "bucket_regional_domain" {
  value = aws_s3_bucket.frontend.bucket_regional_domain_name
}

output "uploads_bucket_name" {
  description = "유저 업로드 S3 버킷 이름"
  value       = aws_s3_bucket.uploads.id
}

output "uploads_bucket_arn" {
  description = "유저 업로드 S3 버킷 ARN (IAM 정책에 사용)"
  value       = aws_s3_bucket.uploads.arn
}

output "uploads_bucket_regional_domain" {
  description = "유저 업로드 S3 버킷 도메인 (Presigned URL 생성 시 참조)"
  value       = aws_s3_bucket.uploads.bucket_regional_domain_name
}
