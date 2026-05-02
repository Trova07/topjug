output "alb_dns_name" {
  value = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB의 Route53 Alias 레코드용 hosted zone ID"
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  value = aws_lb_target_group.api.arn
}
