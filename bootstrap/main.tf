# bootstrap/main.tf
# Run this ONCE manually with your personal AWS credentials to create the
# S3 bucket + DynamoDB table that all pipeline state backends will use.
# After this runs, everything else goes through the pipeline.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
  # No remote backend here — this IS the bootstrap. State stays local.
}

provider "aws" {
  region = var.region
}

variable "region" {
  default = "us-east-1"
}
variable "org" {
  default = "acme"
}
variable "account_suffix" {
  description = "Last 4 digits of your AWS account ID — makes bucket name unique."
}

# ── S3 bucket for Terraform state ────────────────────────────────────────────

resource "aws_s3_bucket" "tfstate" {
  bucket        = "${var.org}-tfstate-${var.region}-${var.account_suffix}"
  force_destroy = false

  tags = {
    purpose    = "terraform-state"
    managed-by = "terraform"
  }
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── DynamoDB table for state locking ─────────────────────────────────────────

resource "aws_dynamodb_table" "tf_locks" {
  name         = "${var.org}-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    purpose    = "terraform-state-lock"
    managed-by = "terraform"
  }
}

output "state_bucket_name" { value = aws_s3_bucket.tfstate.id }
output "lock_table_name"   { value = aws_dynamodb_table.tf_locks.name }
