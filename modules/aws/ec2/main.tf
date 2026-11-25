# ── Local naming helper ───────────────────────────────────────────────────────
# Standard name prefix: <org>-<app>-<env>-<region_short>
# e.g. acme-platform-nonprod-use1

locals {
  region_short = replace(replace(replace(replace(var.region,
    "us-east-1", "use1"),
    "us-west-2", "usw2"),
    "eu-west-1", "euw1"),
    "ap-southeast-1", "apse1"
  )

  name_prefix = "${var.org}-${var.app}-${var.environment}-${local.region_short}"

  common_tags = merge(
    {
      org        = var.org
      app        = var.app
      env        = var.environment
      region     = var.region
      managed-by = "terraform"
      module     = "aws/ec2"
    },
    var.extra_tags
  )
}

# ── AMI selection ─────────────────────────────────────────────────────────────
# If the caller pins an AMI ID we use it directly (recommended for prod).
# Otherwise we find the latest Amazon Linux 2023 for the region.

data "aws_ami" "al2023" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

locals {
  resolved_ami = var.ami_id != "" ? var.ami_id : data.aws_ami.al2023[0].id
}

# ── Security Group ─────────────────────────────────────────────────────────────

resource "aws_security_group" "this" {
  name        = "${local.name_prefix}-ec2-sg"
  description = "Security group for ${local.name_prefix} EC2 instance — managed by Terraform"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-ec2-sg" })

  lifecycle {
    # Prevents destroy + recreate when rules change mid-apply; adjust with care.
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "ingress" {
  for_each = { for idx, rule in var.ingress_rules : tostring(idx) => rule }

  type              = "ingress"
  security_group_id = aws_security_group.this.id
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  security_group_id = aws_security_group.this.id
  description       = "Allow all outbound (restrict via egress_cidr if needed)"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [var.egress_cidr]
}

# ── EC2 Instance ──────────────────────────────────────────────────────────────

resource "aws_instance" "this" {
  ami                         = local.resolved_ami
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = var.associate_public_ip
  key_name                    = var.key_name != "" ? var.key_name : null
  iam_instance_profile        = var.iam_instance_profile != "" ? var.iam_instance_profile : null
  user_data_base64            = var.user_data != "" ? var.user_data : null
  monitoring                  = var.monitoring

  vpc_security_group_ids = [aws_security_group.this.id]

  # IMDSv2 — tokens required; hop limit 1 (containers cannot reach IMDS)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = var.metadata_tokens_required ? "required" : "optional"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size_gb
    encrypted             = var.ebs_encrypted
    kms_key_id            = var.ebs_kms_key_id != "" ? var.ebs_kms_key_id : null
    delete_on_termination = true

    tags = merge(local.common_tags, { Name = "${local.name_prefix}-root" })
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-ec2" })

  lifecycle {
    # Prevent accidental instance replacement when only tags change.
    ignore_changes = [tags["last-deployed"]]
  }
}
