# ── Route53 Hosted Zone ───────────────────────────────────
# terraform apply 후 출력된 nameservers를 도메인 등록업체에 설정해야
# ACM 인증서 검증이 완료됩니다.

resource "aws_route53_zone" "main" {
  name = var.domain_name

  tags = { Name = "${var.project}-hosted-zone" }
}

# ── ACM 인증서 (ap-northeast-2 — ALB용) ──────────────────
# *.domain.com 와일드카드 포함 → www, api 등 서브도메인 모두 커버

resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true # 인증서 교체 시 다운타임 방지
  }

  tags = { Name = "${var.project}-acm-cert" }
}

# ── ACM DNS 검증 레코드 ───────────────────────────────────
# ACM이 소유권 확인을 위해 Route53에 CNAME 레코드 자동 생성

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60

  allow_overwrite = true
}

# ── ACM 검증 완료 대기 ────────────────────────────────────
# 도메인 등록업체에 NS 레코드 설정 후 완료됨 (최대 수십 분 소요)

resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}

# ── Route53 A 레코드 → ALB ────────────────────────────────

resource "aws_route53_record" "apex" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
