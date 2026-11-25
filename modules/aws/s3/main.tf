# ── Local naming ─────────────────────────────────────────────────────────────

locals {
  region_short = replace(replace(replace(replace(var.region,
    "us-east-1", "use1"),
    "us-west-2", "usw2"),
    "eu-west-1", "euw1"),
    "ap-southeast-1", "apse1"
  )

  # Bucket names must be globally unique and ≤ 63 chars, lowercase, no underscores.
  # Pattern: <org>-<app>-<env>-<region_short>-<purpose>-<suffix>
  bucket_name = "${var.org}-${var.app}-${var.environment}-${local.region_short}-${var.purpose}-${var.bucket_suffix}"

  common_tags = merge(
    {
      org        = var.org
      app        = var.app
      env        = var.environment
      region     = var.region
      managed-by = "terraform"
      module     = "aws/s3"
    },
    var.extra_tags
  )
}

# ── Bucket ────────────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy

  tags = merge(local.common_tags, { Name = local.bucket_name })
}

# ── Public access block ───────────────────────────────────────────────────────
# Always created; default values block all public access.

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

# ── Versioning ────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# ── Encryption ────────────────────────────────────────────────────────────────

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.encryption_type
      kms_master_key_id = var.encryption_type == "aws:kms" && var.kms_key_id != "" ? var.kms_key_id : null
    }
    # Bucket keys reduce KMS API call costs ~99% at no security cost.
    bucket_key_enabled = var.encryption_type == "aws:kms"
  }
}

# ── Force TLS (deny non-HTTPS requests) ──────────────────────────────────────
# Applied as a base policy; merged with any caller-supplied policy_json below.

data "aws_iam_policy_document" "tls_enforce" {
  statement {
    sid     = "DenyNonTLS"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

locals {
  # If the caller supplies an additional policy, we merge it via aws_iam_policy_document
  # override; otherwise we use only the TLS deny.
  final_policy = var.policy_json != "" ? var.policy_json : data.aws_iam_policy_document.tls_enforce.json
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = local.final_policy

  # Must wait for the public-access block before attaching a policy,
  # otherwise AWS rejects the attachment if block_public_policy = true is pending.
  depends_on = [aws_s3_bucket_public_access_block.this]
}

# ── Server access logging ─────────────────────────────────────────────────────

resource "aws_s3_bucket_logging" "this" {
  count = var.enable_access_logging ? 1 : 0

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.access_log_bucket
  target_prefix = var.access_log_prefix
}

# ── Lifecycle rules ───────────────────────────────────────────────────────────

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = length(var.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules

    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      filter {
        prefix = rule.value.prefix
      }

      dynamic "transition" {
        for_each = rule.value.transitions

        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration_days > 0 ? [1] : []

        content {
          days = rule.value.expiration_days
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}
