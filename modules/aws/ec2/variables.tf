# ── Identity / tagging ────────────────────────────────────────────────────────

variable "org" {
  type        = string
  description = "Organisation short-name used in every resource name and tag."
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
  description = "AWS region where resources are created."
  default     = "us-east-1"
}

variable "extra_tags" {
  type        = map(string)
  description = "Additional tags merged onto every resource."
  default     = {}
}

# ── Compute ───────────────────────────────────────────────────────────────────

variable "instance_type" {
  type        = string
  description = "EC2 instance type (e.g. t3.micro, m5.large)."
  default     = "t3.micro"
  validation {
    condition     = can(regex("^[a-z][0-9][a-z]?\\.[a-z0-9]+$", var.instance_type))
    error_message = "instance_type does not look like a valid EC2 type (e.g. t3.micro)."
  }
}

variable "ami_id" {
  type        = string
  description = <<-EOT
    AMI ID to launch.  Leave empty to auto-select the latest Amazon Linux 2023 AMI
    for the given region.  Pinning to an explicit AMI ID is recommended for prod to
    avoid uncontrolled OS upgrades.
  EOT
  default     = ""
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID in which to place the instance."
}

variable "vpc_id" {
  type        = string
  description = "VPC ID used to scope the security group."
}

variable "associate_public_ip" {
  type        = bool
  description = "Assign a public IP.  Should be false for prod/nonprod (private subnets)."
  default     = false
}

variable "key_name" {
  type        = string
  description = "EC2 key-pair name for SSH access.  Leave empty to disable SSH key attachment."
  default     = ""
}

variable "root_volume_size_gb" {
  type        = number
  description = "Root EBS volume size in GiB."
  default     = 20
  validation {
    condition     = var.root_volume_size_gb >= 8 && var.root_volume_size_gb <= 500
    error_message = "root_volume_size_gb must be between 8 and 500."
  }
}

variable "root_volume_type" {
  type        = string
  description = "EBS volume type: gp3 (default) | gp2 | io1 | io2"
  default     = "gp3"
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.root_volume_type)
    error_message = "root_volume_type must be gp2, gp3, io1, or io2."
  }
}

variable "ebs_encrypted" {
  type        = bool
  description = "Encrypt the root EBS volume.  Always true in prod/nonprod via policy check."
  default     = true
}

variable "ebs_kms_key_id" {
  type        = string
  description = "KMS key ARN for EBS encryption.  Empty = AWS-managed key (aws/ebs)."
  default     = ""
}

variable "iam_instance_profile" {
  type        = string
  description = "IAM instance profile name to attach.  Leave empty for no profile."
  default     = ""
}

variable "user_data" {
  type        = string
  description = "Base64-encoded user-data script.  Optional."
  default     = ""
  sensitive   = false
}

variable "metadata_tokens_required" {
  type        = bool
  description = "Enforce IMDSv2 (token-required).  Disabling is a Checkov HIGH finding."
  default     = true
}

variable "monitoring" {
  type        = bool
  description = "Enable detailed CloudWatch monitoring."
  default     = true
}

# ── Networking / Security Group ───────────────────────────────────────────────

variable "ingress_rules" {
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  description = <<-EOT
    Ingress rules for the instance security group.  Default: empty (no inbound).
    For prod, prefer VPC-internal CIDRs only; a policy check blocks 0.0.0.0/0 on SSH.
  EOT
  default     = []
}

variable "egress_cidr" {
  type        = string
  description = "Egress CIDR.  Defaults to 0.0.0.0/0; restrict to VPC CIDR for high-sec workloads."
  default     = "0.0.0.0/0"
}
