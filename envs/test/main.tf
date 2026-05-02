terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

# ── 방화벽 규칙 ───────────────────────────────────────────

resource "google_compute_firewall" "allow_ssh" {
  name    = "topjug-test-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["topjug-test"]
}

resource "google_compute_firewall" "allow_api" {
  name    = "topjug-test-allow-api"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["3000"] # API 서버 포트
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["topjug-test"]
}

# ── GCE VM ────────────────────────────────────────────────

resource "google_compute_instance" "test" {
  name         = "topjug-test"
  machine_type = var.machine_type
  zone         = var.gcp_zone

  tags = ["topjug-test"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20 # GB
    }
  }

  network_interface {
    network = "default"

    access_config {
      # 공인 IP 자동 할당
    }
  }

  # 부팅 시 Docker + Docker Compose 설치
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y ca-certificates curl gnupg

    # Docker 공식 GPG 키 추가
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Docker apt 저장소 추가
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    # 기본 유저도 docker 명령 사용 가능하게
    usermod -aG docker $(getent passwd 1000 | cut -d: -f1) 2>/dev/null || true

    echo "Docker 설치 완료" >> /var/log/startup.log
  EOF

  labels = {
    env     = "test"
    project = "topjug"
  }
}
