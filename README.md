# 탑저그 (TopJug) 🧗

> 여러 암장의 정보 및 이벤트를 한눈에 확인하고, 나만의 클라이밍 기록까지 관리하는 클라이밍 플랫폼

---

## 서비스 소개

클라이머라면 여러 암장을 다니면서 각 암장의 세팅 일정, 이벤트, 회원권 정보를 따로따로 확인해야 했습니다.  
**탑저그**는 이 모든 정보를 하나의 플랫폼에서 해결합니다.

- 📍 **주변 암장 탐색** — 위치 기반으로 근처 암장을 빠르게 찾기
- 📅 **세팅 일정 통합** — 여러 암장의 루트 세팅 일정을 한 화면에서 확인
- 🎫 **회원권 관리** — 보유한 회원권 만료일 및 잔여 횟수 한눈에 파악
- 📈 **클라이밍 기록** — 방문한 암장과 완등한 문제 난이도(V-scale) 기록
- 🔔 **세팅 알림** — 관심 암장의 새 세팅 등록 시 푸시 알림

---

## 기술 스택

### 인프라

| 영역 | 기술 |
|------|------|
| Cloud | AWS |
| IaC | Terraform |
| Container | ECS Fargate |
| Database | RDS PostgreSQL |
| Cache | Redis (ECS) |
| CDN | CloudFront + S3 |
| Registry | ECR |

### 애플리케이션

| 영역 | 기술 |
|------|------|
| Frontend | PWA (모바일 웹) |
| 위치 검색 | PostGIS |
| 로그 | CloudWatch Logs |

---

## 아키텍처

```
[사용자 브라우저 / PWA]
         │
    [CloudFront]
    ├── S3 (프론트엔드 정적 파일)
    └── ALB (API 요청 /api/*)
              │
         [ECS Fargate]
         ├── API 서버 Task
         └── Redis Task (캐시, Cloud Map: redis.topjug.local)
                   │
              [RDS PostgreSQL]
              (PostGIS 위치 검색)
```

**네트워크 전략**
- NAT Gateway 없이 Public Subnet + Security Group으로 인바운드 통제
- ECS Task SG: 인바운드 VPC CIDR 한정 / 아웃바운드 전체 허용
- RDS SG: 인바운드·아웃바운드 모두 VPC CIDR 한정

---

## 인프라 디렉토리 구조

```
topjug/
├── main.tf                    # Provider 및 모듈 호출
├── variables.tf               # 전역 변수 정의
├── outputs.tf                 # 주요 리소스 출력값
├── terraform.tfvars.example   # 환경변수 템플릿
└── modules/
    ├── networking/            # VPC, 서브넷, IGW, Security Group
    ├── ecr/                   # 컨테이너 이미지 저장소
    ├── loadbalancer/          # ALB, Target Group, Listener
    ├── compute/               # ECS 클러스터, API/Redis 서비스, IAM
    ├── database/              # RDS PostgreSQL
    ├── storage/               # S3 버킷
    └── cdn/                   # CloudFront 배포
```

---

## 시작하기

### 사전 요구사항

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6.0
- [AWS CLI](https://aws.amazon.com/ko/cli/) 설치 및 자격증명 설정
- AWS IAM 계정 (필요 권한: ECS, RDS, S3, CloudFront, ECR, IAM)

### 1. 환경변수 설정

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 파일을 열어 `db_password` 등 필수 값을 수정합니다.

> ⚠️ `terraform.tfvars`는 `.gitignore`에 포함되어 있습니다. 절대 커밋하지 마세요.

### 2. 초기화 및 배포

```bash
# Provider 및 모듈 초기화
terraform init

# 변경사항 미리 확인
terraform plan

# 인프라 생성
terraform apply
```

### 3. 배포 완료 후 출력값 확인

```bash
terraform output

# 예시 출력:
# alb_dns_name      = "topjug-alb-xxxx.ap-northeast-2.elb.amazonaws.com"
# cloudfront_domain = "xxxx.cloudfront.net"
# ecr_api_url       = "123456789.dkr.ecr.ap-northeast-2.amazonaws.com/topjug-api"
```

### 4. API 서버 첫 배포 (ECR 이미지 푸시)

```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 \
  | docker login --username AWS --password-stdin {ECR_URL}

# 이미지 빌드 및 푸시
docker build -t topjug-api ./backend
docker tag topjug-api:latest {ECR_URL}/topjug-api:latest
docker push {ECR_URL}/topjug-api:latest

# ECS 서비스 재배포
aws ecs update-service \
  --cluster topjug-cluster \
  --service topjug-api \
  --force-new-deployment
```

---

## 주요 설정값

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `aws_region` | `ap-northeast-2` | 서울 리전 |
| `vpc_cidr` | `10.0.0.0/16` | VPC 대역 |
| `db_instance_class` | `db.t4g.micro` | RDS 사양 (수직확장 시 변경) |
| `api_cpu` | `256` | API Task CPU (1024 = 1 vCPU) |
| `api_memory` | `512` | API Task 메모리 (MiB) |
| `api_desired_count` | `1` | 실행할 API Task 수 |

---

## 스케일업 가이드

트래픽 증가 시 `terraform.tfvars`에서 아래 값만 변경 후 `terraform apply`:

```hcl
# RDS 수직확장
db_instance_class = "db.t4g.small"  # micro → small → medium

# API Task 수평확장
api_cpu           = 512
api_memory        = 1024
api_desired_count = 2
```

---

## 팀

| 역할 | 담당 |
|------|------|
| 인프라 | 승현 |
| 백엔드 | - |
| 프론트엔드 | - |
| 기획 | - |
