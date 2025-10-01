# -----------------------------
# Domain + subdomain
# -----------------------------
domain_name = "weathertracker.online"
subdomain   = "www"

# Content path (relative to this folder)
website_content_path = "../src"

# -----------------------------
# AWS
# -----------------------------
aws_region            = "us-east-1"
s3_bucket_name_prefix = "weather-tracker-app-bucket"
acm_certificate_arn   = "<ARN of Certificate in AWS Certificate Manager"

# -----------------------------
# Azure
# -----------------------------
azure_subscription_id       = "<Subscription ID>"
azure_tenant_id             = "<Tenant ID>"
azure_resource_group_name   = "rg-static-website"
azure_location              = "East US"
storage_account_name_prefix = "weatherweb"

# -----------------------------
# Manual DR Failover
# -----------------------------
primary_weight   = "100"
secondary_weight = "0"