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
