# ── 프론트엔드 S3 버킷 ────────────────────────────────────

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "frontend" {
  bucket = "${var.project}-frontend-${random_id.suffix.hex}"

  tags = { Name = "${var.project}-frontend" }
}

# 퍼블릭 접근 차단 (CloudFront OAC를 통해서만 접근)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 버킷 버전 관리 (배포 롤백 용이)
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ── 유저 업로드 S3 버킷 ────────────────────────────────────
# 프로필 사진, 암장 이미지 등 유저 생성 콘텐츠 저장
# API 서버가 Presigned URL 발급 → 클라이언트가 직접 업로드

resource "aws_s3_bucket" "uploads" {
  bucket = "${var.project}-uploads-${random_id.suffix.hex}"

  tags = { Name = "${var.project}-uploads" }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CORS: 브라우저에서 Presigned URL로 직접 PUT 업로드 허용
resource "aws_s3_bucket_cors_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  cors_rule {
    allowed_methods = ["PUT", "POST", "GET"]
    allowed_origins = ["*"] # 도메인 확정 후 CloudFront 도메인으로 좁히기
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }
}

# 업로드 파일 수명 주기 (오래된 파일 자동 정리 — 선택 사항)
resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    id     = "delete-incomplete-multipart"
    status = "Enabled"

    filter {
      prefix = "" # 전체 오브젝트 대상
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }
}
