output "vm_public_ip" {
  description = "테스트 서버 공인 IP (SSH 접속 및 API 호출용)"
  value       = google_compute_instance.test.network_interface[0].access_config[0].nat_ip
}

output "ssh_command" {
  description = "SSH 접속 명령어"
  value       = "gcloud compute ssh topjug-test --zone=${var.gcp_zone}"
}

output "api_url" {
  description = "API 베이스 URL"
  value       = "http://${google_compute_instance.test.network_interface[0].access_config[0].nat_ip}:3000"
}
