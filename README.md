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
- 🔔 **알림** — 회원권 만료 임박, 잔여 횟수 1회, 장비 교체 필요 시 푸시 알림

---

## 기술 스택

### 인프라

| 영역 | 기술 | 선택 이유 |
|------|------|-----------|
| Cloud | AWS | 팀 친숙도 + 생태계 |
| IaC | Terraform | 코드로 인프라 관리, 재현 가능 |
| Container | ECS EC2 Launch Type | Fargate 대비 비용 절감 (~30%) |
| Database | RDS PostgreSQL | PostGIS 위치 검색, 관계형 데이터 |
| Cache | Redis (ECS) | ElastiCache 대비 비용 절감 |
| CDN | CloudFront + S3 | 정적 파일 배포 + API 라우팅 |
| Registry | ECR | AWS 네이티브 컨테이너 저장소 |

### 애플리케이션

| 영역 | 기술 |
|------|------|
| Frontend | PWA (모바일 웹) |
| 위치 검색 | PostGIS (PostgreSQL 확장) |
| 로그 | CloudWatch Logs |

---

## 아키텍처

```
[사용자 브라우저 / PWA]
         │
    [CloudFront]
    ├── S3 (프론트엔드 정적 파일)           ← 기본 경로 /
    └── ALB (API 요청 /api/*)              ← /api/* 경로
              │
    [ECS EC2 (t3.small)]
    ├── API 서버 Task (512MB)
    └── Redis Task (256MB, Cloud Map: redis.topjug.local)
              │
         [RDS PostgreSQL]
         (PostGIS 위치 검색)

    [S3 Uploads]  ← 프로필 사진, 암장 이미지 (Presigned URL)
```

**네트워크 전략**

- **NAT Gateway 없음** — Public Subnet + Security Group 인바운드 통제로 대체
  - NAT Gateway는 월 ~$32 고정 비용 발생, MVP 단계에서 불필요
  - ECS SG: 인바운드 VPC CIDR 한정 / 아웃바운드 전체 허용 (ECR 이미지 pull 등)
  - RDS SG: 인바운드·아웃바운드 모두 VPC CIDR 한정 (외부 직접 접근 차단)

---

## 왜 이 아키텍처인가 (의사결정 기록)

팀 논의에서 아래와 같은 **멀티리전 고가용성 아키텍처**가 참고 자료로 제시되었습니다.

```
Route 53 → Region 1 / Region 2
  Transit Gateway Peering
  S3 CRR (Cross-Region Replication)
  ElastiCache Global Database
  Secrets Manager CCR
  DynamoDB
```

MVP 단계에서 이 구조를 그대로 채택하지 않은 이유는 다음과 같습니다.

| 항목 | 멀티리전 아키텍처 | 현재 선택 | 이유 |
|------|------------------|-----------|------|
| 리전 수 | 2개 | 1개 (서울) | 비용 2배, 초기 사용자 전부 국내 |
| Transit Gateway | 있음 | 없음 | 단일 리전에서 불필요, 월 ~$36 |
| S3 CRR | 있음 | 없음 | 단일 리전 S3로 충분 |
| ElastiCache | Global DB | ECS Redis | 월 ~$25 → 거의 $0 |
| Secrets Manager | 있음 | SSM Parameter Store | 기능 동일, SSM이 더 저렴 |
| DynamoDB | 있음 | PostgreSQL | 이미 RDS 사용 중, 중복 불필요 |

**결론:** 현재 아키텍처는 초기 트래픽과 팀 규모에 맞게 비용을 최소화하면서도,  
트래픽 증가 시 수직·수평 확장이 가능하도록 설계되었습니다.  
멀티리전 전환이 필요한 시점이 오면 Terraform 모듈 단위로 점진적으로 추가할 수 있습니다.

---

## 인프라 디렉토리 구조

```
topjug/
├── main.tf                    # Provider 및 모듈 호출
├── variables.tf               # 전역 변수 정의
├── outputs.tf                 # 주요 리소스 출력값
├── terraform.tfvars.example   # 환경변수 템플릿
├── modules/
│   ├── networking/            # VPC, 서브넷, IGW, Security Group
│   ├── ecr/                   # 컨테이너 이미지 저장소
│   ├── loadbalancer/          # ALB, Target Group, Listener
│   ├── compute/               # ECS 클러스터, API/Redis 서비스, IAM
│   ├── database/              # RDS PostgreSQL
│   ├── storage/               # S3 (프론트엔드 + 유저 업로드)
│   └── cdn/                   # CloudFront 배포
└── envs/
    └── test/                  # GCP 테스트 서버 (무료 크레딧 활용)
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── docker-compose.yml
```

---

## 시작하기 (AWS 프로덕션)

### 사전 요구사항

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.6.0
- [AWS CLI](https://aws.amazon.com/ko/cli/) 설치 및 자격증명 설정
- AWS IAM 계정 (필요 권한: ECS, RDS, S3, CloudFront, ECR, IAM, SSM)

### 1. 환경변수 설정

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars` 파일을 열어 `db_password` 등 필수 값을 수정합니다.

> ⚠️ `terraform.tfvars`는 `.gitignore`에 포함되어 있습니다. 절대 커밋하지 마세요.

### 2. 초기화 및 배포

```bash
# 루트 디렉토리에서 실행
terraform init
terraform plan
terraform apply
```

### 3. 배포 완료 후 출력값 확인

```bash
terraform output

# 예시 출력:
# alb_dns_name          = "topjug-alb-xxxx.ap-northeast-2.elb.amazonaws.com"
# cloudfront_domain     = "xxxx.cloudfront.net"
# ecr_api_url           = "123456789.dkr.ecr.ap-northeast-2.amazonaws.com/topjug-api"
# uploads_bucket_name   = "topjug-uploads-xxxx"
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

### 5. DB 초기화 (첫 배포 시 1회)

API 서버 첫 실행 전, PostgreSQL에 PostGIS 확장을 활성화합니다.

```sql
-- RDS에 접속 후 실행
CREATE EXTENSION IF NOT EXISTS postgis;
```

---

## 시작하기 (GCP 테스트 서버)

> GCP 무료 크레딧($300)을 활용한 테스트 환경입니다. 프로덕션 AWS와 완전히 분리됩니다.

### 1. GCP 세팅 (최초 1회)

```bash
gcloud auth login
gcloud projects create topjug-test-xxxxxx
gcloud config set project topjug-test-xxxxxx
gcloud auth application-default login
gcloud services enable compute.googleapis.com
```

### 2. VM 생성

```bash
cd envs/test
cp terraform.tfvars.example terraform.tfvars  # gcp_project 값 수정

terraform init
terraform apply

# 완료 후 접속 정보 확인
terraform output
# ssh_command = "gcloud compute ssh topjug-test --zone=asia-northeast3-a"
# api_url     = "http://x.x.x.x:3000"
```

### 3. docker-compose 실행

```bash
# docker-compose.yml VM에 복사
gcloud compute scp docker-compose.yml topjug-test:~ --zone=asia-northeast3-a

# VM 접속
gcloud compute ssh topjug-test --zone=asia-northeast3-a

# VM 안에서 실행
DB_PASSWORD=원하는비밀번호 docker compose up -d
```

---

## 이미지 업로드 흐름 (Presigned URL)

프로필 사진, 암장 이미지 등은 API 서버를 거치지 않고 클라이언트가 S3에 직접 업로드합니다.  
API 서버는 S3 접근 권한(IAM)을 이용해 임시 업로드 URL만 발급하는 역할을 합니다.

```
클라이언트                   API 서버                    S3
   │                           │                          │
   │── 업로드 URL 요청 ────────▶│                          │
   │                           │── Presigned URL 생성 ──▶│
   │                           │◀── URL 반환 ─────────────│
   │◀── { uploadUrl, fileKey } ─│                          │
   │                           │                          │
   │─── PUT {uploadUrl} (파일 직접 업로드) ───────────────▶│
   │                           │                          │
   │── 저장된 fileKey 전달 ────▶│                          │
   │                           │── DB에 URL 저장 ─────────│
```

---

## 주요 설정값

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `aws_region` | `ap-northeast-2` | 서울 리전 |
| `vpc_cidr` | `10.0.0.0/16` | VPC 대역 |
| `db_instance_class` | `db.t4g.micro` | RDS 사양 (수직확장 시 변경) |
| `ec2_instance_type` | `t3.small` | ECS EC2 인스턴스 사양 |
| `api_desired_count` | `1` | 실행할 API Task 수 |

---

## 스케일업 가이드

트래픽 증가 시 `terraform.tfvars`에서 아래 값만 변경 후 `terraform apply`:

```hcl
# RDS 수직확장
db_instance_class = "db.t4g.small"

# EC2 인스턴스 업그레이드 (더 많은 Task 수용)
ec2_instance_type = "t3.medium"

# API Task 수평확장
api_desired_count = 2
```

---

## 팀

| 역할 | 담당 |
|------|------|
| 인프라 | 승현 |
| 백엔드 | 승환, 준우 |
| 프론트엔드 | 현수 |
