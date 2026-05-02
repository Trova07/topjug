variable "gcp_project" {
  description = "GCP 프로젝트 ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP 리전"
  type        = string
  default     = "asia-northeast3" # 서울
}

variable "gcp_zone" {
  description = "GCP 존"
  type        = string
  default     = "asia-northeast3-a"
}

variable "machine_type" {
  description = "GCE 인스턴스 머신 타입"
  type        = string
  default     = "e2-small" # 2vCPU / 2GB — API + Postgres + Redis 감당 가능
}
