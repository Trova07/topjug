# CDN 모듈은 CloudFront 때문에 반드시 us-east-1 provider 필요
# 호출부(main.tf)에서 providers = { aws = aws.us_east_1 } 로 주입
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

# ── CloudFront OAC (S3 접근용) ────────────────────────────

resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ── CloudFront Distribution ───────────────────────────────

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  default_root_object = "index.html"
  price_class         = "PriceClass_200" # 미국, 유럽, 아시아 엣지 (한국 포함)
  comment             = "${var.project} frontend"

  # Origin 1: S3 (정적 파일)
  origin {
    domain_name              = var.s3_bucket_domain
    origin_id                = "s3-frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  # Origin 2: ALB (API 서버)
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "alb-api"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # ALB HTTPS 설정 전까지
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # 기본 캐시 동작: S3 정적 파일
  default_cache_behavior {
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    min_ttl     = 0
    default_ttl = 3600  # 1시간 캐시
    max_ttl     = 86400 # 최대 1일
  }

  # /api/* 경로는 ALB로 라우팅 (캐시 없음)
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "alb-api"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "Origin"]
      cookies { forward = "all" }
    }

    min_ttl     = 0
    default_ttl = 0 # API는 캐시 안 함
    max_ttl     = 0
  }

  # SPA 라우팅: 404 → index.html (React Router 등 클라이언트 라우팅 지원)
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true # 도메인 연결 전 기본 인증서 사용
    # 도메인 연결 후 아래로 교체:
    # acm_certificate_arn      = var.acm_certificate_arn
    # ssl_support_method       = "sni-only"
    # minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = { Name = "${var.project}-cloudfront" }
}

# ── S3 버킷 정책 (CloudFront OAC만 허용) ─────────────────
# 순환 의존성 방지를 위해 CDN 모듈에서 관리

resource "aws_s3_bucket_policy" "frontend" {
  bucket = var.s3_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAC"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "arn:aws:s3:::${var.s3_bucket_id}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.main.arn
          }
        }
      }
    ]
  })
}
