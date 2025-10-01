# -----------------------------
# Inputs: AWS / Domain
# -----------------------------
variable "aws_region" {
  description = "AWS region for the provider (S3/Route 53/ACM API calls)."
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Root domain managed in Route 53 (public hosted zone already exists)."
  type        = string
}

variable "subdomain" {
  description = "Subdomain to serve the site (usually 'www')."
  type        = string
  default     = "www"
}

# -----------------------------
# Inputs: S3 & Content
# -----------------------------
variable "s3_bucket_name_prefix" {
  description = "Prefix for the S3 bucket name (lowercase letters, numbers, hyphens)."
  type        = string
  default     = "weather-tracker-site"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.s3_bucket_name_prefix))
    error_message = "Use 3-63 chars, lowercase letters/numbers/hyphens; must start/end with a letter or number."
  }
}

variable "website_content_path" {
  description = "Local path to the site files; must contain index.html at the root."
  type        = string
  default     = "../src"
}

# -----------------------------
# Inputs: Certificate (AWS ACM)
# -----------------------------
variable "acm_certificate_arn" {
  description = "ARN of the ISSUED ACM cert in us-east-1 for the 'www' hostname."
  type        = string
}

# -----------------------------
# Inputs: Azure
# -----------------------------
variable "azure_subscription_id" {
  description = "Azure subscription ID."
  type        = string
}

variable "azure_tenant_id" {
  description = "Azure tenant ID."
  type        = string
}

variable "azure_resource_group_name" {
  description = "Azure resource group for the storage account."
  type        = string
  default     = "rg-static-website"
}

variable "azure_location" {
  description = "Azure region for the storage account."
  type        = string
  default     = "East US"
}

variable "storage_account_name_prefix" {
  description = "Lowercase letters/numbers; final storage account name is prefix + 6-char random (<=24 total)."
  type        = string
  default     = "weatherweb"

  validation {
    condition     = can(regex("^[a-z0-9]{3,18}$", var.storage_account_name_prefix))
    error_message = "Use 3-18 lowercase letters/numbers."
  }
}

# -----------------------------
# Inputs: DNS weights (manual failover)
# -----------------------------
variable "primary_weight" {
  description = "Weight for primary (CloudFront). Set to 100 for normal ops."
  type        = number
  default     = 100
}

variable "secondary_weight" {
  description = "Weight for secondary (Azure). Set to 100 to force DR."
  type        = number
  default     = 0
}
