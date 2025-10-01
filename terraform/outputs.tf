output "site_fqdn" {
  description = "User-facing hostname."
  value       = "${var.subdomain}.${var.domain_name}"
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "s3_bucket_name" {
  description = "S3 bucket name."
  value       = aws_s3_bucket.site.bucket
}

output "route53_zone_id" {
  description = "Hosted zone ID."
  value       = data.aws_route53_zone.main.zone_id
}
