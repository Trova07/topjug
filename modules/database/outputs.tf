# endpoint = "hostname:5432" 형태로 오기 때문에 호스트만 분리해서 넘김
output "db_endpoint" {
  description = "포트 포함 전체 endpoint (참고용)"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "db_host" {
  description = "호스트명만 (포트 제외) — 앱의 DB_HOST 환경변수에 사용"
  value       = aws_db_instance.main.address
  sensitive   = true
}

output "db_port" {
  description = "DB 포트 번호"
  value       = aws_db_instance.main.port
}
