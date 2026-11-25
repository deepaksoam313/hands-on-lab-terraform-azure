variable "org" {
  type    = string
  default = "acme"
}

variable "app" {
  type    = string
  default = "platform"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

# ── Networking (passed in from your existing VPC) ─────────────────────────────

variable "vpc_id" {
  type        = string
  description = "VPC ID where resources will be placed."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID for the EC2 instance."
}

# ── EC2 ───────────────────────────────────────────────────────────────────────

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

# ── S3 ────────────────────────────────────────────────────────────────────────

variable "bucket_suffix" {
  type        = string
  description = "Short unique suffix for the bucket name (e.g. last-4 of account ID)."
}
