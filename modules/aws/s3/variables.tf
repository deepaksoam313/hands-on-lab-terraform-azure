# ── Identity / tagging ────────────────────────────────────────────────────────

variable "org" {
  type        = string
  description = "Organisation short-name used in the bucket name and tags."
  validation {
    condition     = can(regex("^[a-z0-9-]{2,16}$", var.org))
    error_message = "org must be 2-16 lowercase alphanumeric characters or hyphens."
  }
}

variable "app" {
  type        = string
  description = "Application or platform name."
  validation {
    condition     = can(regex("^[a-z0-9-]{2,32}$", var.app))
    error_message = "app must be 2-32 lowercase alphanumeric characters or hyphens."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment: sandbox | nonprod | prod"
  validation {
    condition     = contains(["sandbox", "nonprod", "prod"], var.environment)
    error_message = "environment must be one of: sandbox, nonprod, prod."
  }
}

variable "region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "bucket_suffix" {
  type        = string
  description = <<-EOT
    Short suffix appended to the generated bucket name to make it globally unique.
    Typically the AWS account ID last-4 or a short random string.
    Bucket name pattern: <org>-<app>-<env>-<region_short>-<purpose>-<suffix>
  EOT
}

variable "purpose" {
  type        = string
  description = "Short label for the bucket's purpose: logs | artifacts | data | backup | state"
  default     = "data"
  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.purpose))
    error_message = "purpose must be 2-20 lowercase alphanumeric characters or hyphens."
  }
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags merged onto every resource."
  default     = {}
}

# ── Security ──────────────────────────────────────────────────────────────────

variable "force_destroy" {
  type        = bool
  description = <<-EOT
    Allow Terraform to destroy the bucket even if it contains objects.
    Set true only for sandbox/ephemeral environments.
    A policy check blocks force_destroy=true in prod.
  EOT
  default     = false
}

variable "block_public_acls" {
  type        = bool
  description = "Block public ACLs."
  default     = true
}

variable "block_public_policy" {
  type        = bool
  description = "Block public bucket policies."
  default     = true
}

variable "ignore_public_acls" {
  type        = bool
  description = "Ignore existing public ACLs."
  default     = true
}

variable "restrict_public_buckets" {
  type        = bool
  description = "Restrict public bucket policies."
  default     = true
}

variable "enable_versioning" {
  type        = bool
  description = "Enable S3 versioning.  Should be true for state buckets and prod data."
  default     = true
}

variable "encryption_type" {
  type        = string
  description = "SSE algorithm: AES256 (SSE-S3) or aws:kms (SSE-KMS)."
  default     = "aws:kms"
  validation {
    condition     = contains(["AES256", "aws:kms"], var.encryption_type)
    error_message = "encryption_type must be AES256 or aws:kms."
  }
}

variable "kms_key_id" {
  type        = string
  description = "KMS key ARN for SSE-KMS.  Required when encryption_type = aws:kms.  Empty = aws/s3 managed key."
  default     = ""
  sensitive   = false
}

variable "enable_access_logging" {
  type        = bool
  description = "Send server access logs to a designated logging bucket."
  default     = false
}

variable "access_log_bucket" {
  type        = string
  description = "Target bucket for server access logs.  Required when enable_access_logging = true."
  default     = ""
}

variable "access_log_prefix" {
  type        = string
  description = "Key prefix for access log objects."
  default     = "s3-access-logs/"
}

# ── Lifecycle ─────────────────────────────────────────────────────────────────

variable "lifecycle_rules" {
  type = list(object({
    id      = string
    enabled = bool
    prefix  = string
    transitions = list(object({
      days          = number
      storage_class = string
    }))
    expiration_days = number # 0 = no expiration
  }))
  description = "Lifecycle rules for the bucket.  Empty list = no rules."
  default     = []
}

# ── Policy ────────────────────────────────────────────────────────────────────

variable "policy_json" {
  type        = string
  description = "Optional bucket policy JSON.  Applied as-is.  Validate with conftest before use."
  default     = ""
}
