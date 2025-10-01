# -----------------------------
# Locals
# -----------------------------
locals {
  fqdn = "${var.subdomain}.${var.domain_name}"

  mime_types = {
    html = "text/html"
    htm  = "text/html"
    css  = "text/css"
    js   = "application/javascript"
    json = "application/json"
    png  = "image/png"
    jpg  = "image/jpeg"
    jpeg = "image/jpeg"
    gif  = "image/gif"
    svg  = "image/svg+xml"
    ico  = "image/x-icon"
    txt  = "text/plain"
    xml  = "application/xml"
    map  = "application/json"
  }
}

# -----------------------------
# Random suffixes for unique names
# -----------------------------
resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "random_string" "az_suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

# -----------------------------
# Route 53: public hosted zone lookup
# -----------------------------
data "aws_route53_zone" "main" {
  name         = "${var.domain_name}."
  private_zone = false
}

# -----------------------------
# S3: static website hosting (public)
# -----------------------------
resource "aws_s3_bucket" "site" {
  bucket = "${var.s3_bucket_name_prefix}-${random_string.suffix.result}"
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "PublicReadGetObject",
      Effect    = "Allow",
      Principal = "*",
      Action    = ["s3:GetObject"],
      Resource  = "arn:aws:s3:::${aws_s3_bucket.site.id}/*"
    }]
  })
  depends_on = [aws_s3_bucket_public_access_block.site]
}

# -----------------------------
# S3: upload all site files recursively
# -----------------------------
resource "aws_s3_object" "site_files" {
  for_each = {
    for f in fileset(var.website_content_path, "**") :
    f => "${var.website_content_path}/${f}"
  }

  bucket = aws_s3_bucket.site.id
  key    = each.key
  source = each.value
  etag   = filemd5(each.value)

  content_type = lookup(
    local.mime_types,
    lower(element(reverse(split(".", each.key)), 0)),
    "application/octet-stream"
  )

  depends_on = [
    aws_s3_bucket_website_configuration.site,
    aws_s3_bucket_policy.public_read
  ]
}

# -----------------------------
# CloudFront: custom security headers (NO HSTS)
# -----------------------------
resource "aws_cloudfront_response_headers_policy" "no_hsts_security_headers" {
  name = "no-hsts-security-headers"

  security_headers_config {
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "SAMEORIGIN"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    xss_protection {
      protection = true
      mode_block = true
      override   = true
    }
    # NOTE: strict_transport_security intentionally NOT set to allow HTTP fallback on DR.
  }
}

# -----------------------------
# CloudFront: managed cache policy
# -----------------------------
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# -----------------------------
# CloudFront: distribution (origin = S3 website endpoint)
# -----------------------------
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Weather Tracker (primary)"
  default_root_object = "index.html"

  aliases = [local.fqdn]

  origin {
    domain_name = aws_s3_bucket_website_configuration.site.website_endpoint
    origin_id   = "s3-website-origin"

    custom_origin_config {
      origin_protocol_policy = "http-only"
      http_port              = 80
      https_port             = 443
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3-website-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    response_headers_policy_id = aws_cloudfront_response_headers_policy.no_hsts_security_headers.id
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  depends_on = [aws_s3_bucket_website_configuration.site]
}

# -----------------------------
# Azure: resource group + storage account (HTTP allowed)
# -----------------------------
locals {
  azure_storage_account_name = lower(substr("${var.storage_account_name_prefix}${random_string.az_suffix.result}", 0, 24))
}

resource "azurerm_resource_group" "rg" {
  name     = var.azure_resource_group_name
  location = var.azure_location
}

resource "azurerm_storage_account" "storage" {
  name                            = local.azure_storage_account_name
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  allow_nested_items_to_be_public = true

  # DR will be HTTP-only; allow HTTP (v4 arg name)
  https_traffic_only_enabled = false
}

resource "azurerm_storage_account_static_website" "site" {
  storage_account_id = azurerm_storage_account.storage.id
  index_document     = "index.html"
  error_404_document = "index.html"
}

# -----------------------------
# Azure: upload all site files to $web
# -----------------------------
resource "azurerm_storage_blob" "site_files" {
  for_each = {
    for f in fileset(var.website_content_path, "**") :
    f => "${var.website_content_path}/${f}"
  }

  name                   = each.key
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = "$web"
  type                   = "Block"
  source                 = each.value

  content_type = lookup(
    local.mime_types,
    lower(element(reverse(split(".", each.key)), 0)),
    "application/octet-stream"
  )

  depends_on = [azurerm_storage_account_static_website.site]
}

# -----------------------------
# Azure: host-only endpoint for DNS use
# -----------------------------
locals {
  azure_web_host = element(
    split("/", replace(azurerm_storage_account.storage.primary_web_endpoint, "https://", "")),
    0
  )
}

# -----------------------------
# Route 53: Azure custom-domain validation (asverify CNAME)
# -----------------------------
resource "aws_route53_record" "azure_custom_domain_validation" {
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = "asverify.${local.fqdn}" # asverify.www.example.com
  type            = "CNAME"
  ttl             = 300
  records         = ["asverify.${local.azure_web_host}"] # asverify.<account>.z13.web.core.windows.net
  allow_overwrite = true
}

# -----------------------------
# Azure: register custom domain (indirect CNAME) via az CLI (re-run every apply)
# -----------------------------
resource "null_resource" "azure_register_custom_domain" {
  triggers = {
    sa_name = azurerm_storage_account.storage.name
    fqdn    = local.fqdn
    ts      = timestamp() # forces this to run on every apply
  }

  depends_on = [
    aws_route53_record.azure_custom_domain_validation,
    azurerm_storage_account.storage
  ]

  provisioner "local-exec" {
    command = "az storage account update --name ${azurerm_storage_account.storage.name} --resource-group ${azurerm_resource_group.rg.name} --custom-domain ${local.fqdn} --use-subdomain true --only-show-errors"
  }
}

# -----------------------------
# Route 53: weighted records (manual DR toggle)
# -----------------------------
resource "aws_route53_record" "www_primary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.fqdn
  type    = "CNAME"
  ttl     = 60

  set_identifier = "primary-cloudfront"

  weighted_routing_policy {
    weight = var.primary_weight
  }

  records         = [aws_cloudfront_distribution.site.domain_name]
  allow_overwrite = true
}

resource "aws_route53_record" "www_secondary" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.fqdn
  type    = "CNAME"
  ttl     = 60

  set_identifier = "secondary-azure"

  weighted_routing_policy {
    weight = var.secondary_weight
  }

  records         = [local.azure_web_host]
  allow_overwrite = true

  depends_on = [null_resource.azure_register_custom_domain]
}
