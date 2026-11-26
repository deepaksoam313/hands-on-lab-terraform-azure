# policies/terraform.rego
# OPA/conftest policy rules evaluated against `terraform show -json tfplan`.
# Run: conftest test plan.json --policy policies/ --namespace terraform

package terraform

import future.keywords.in
import future.keywords.every

# ─────────────────────────────────────────────────────────────────────────────
# Helper: collect all resource changes from the plan
# ─────────────────────────────────────────────────────────────────────────────

resource_changes[change] {
  change := input.resource_changes[_]
  change.change.actions[_] in {"create", "update"}
}

# ─────────────────────────────────────────────────────────────────────────────
# RULE 1 — EC2: EBS encryption must be enabled
# ─────────────────────────────────────────────────────────────────────────────

deny[msg] {
  change := resource_changes[_]
  change.type == "aws_instance"
  block := change.change.after.root_block_device[_]
  block.encrypted == false
  msg := sprintf(
    "DENY [EBS-ENCRYPT] aws_instance '%s': root_block_device.encrypted must be true. Got: false",
    [change.address]
  )
}

# ─────────────────────────────────────────────────────────────────────────────
# RULE 2 — EC2: IMDSv2 must be enforced (http_tokens = required)
# ─────────────────────────────────────────────────────────────────────────────

deny[msg] {
  change := resource_changes[_]
  change.type == "aws_instance"
  meta := change.change.after.metadata_options[_]
  meta.http_tokens != "required"
  msg := sprintf(
    "DENY [IMDSV2] aws_instance '%s': metadata_options.http_tokens must be 'required'. Got: '%s'",
    [change.address, meta.http_tokens]
  )
}

# ─────────────────────────────────────────────────────────────────────────────
# RULE 3 — EC2: No public IP allowed in nonprod/prod
# ─────────────────────────────────────────────────────────────────────────────

deny[msg] {
  change := resource_changes[_]
  change.type == "aws_instance"
  change.change.after.associate_public_ip_address == true
  # Allow in sandbox (the pipeline passes environment via var; here we check the tag)
  tags := change.change.after.tags
  tags.env != "sandbox"
  msg := sprintf(
    "DENY [PUBLIC-IP] aws_instance '%s': associate_public_ip_address must be false in env '%s'",
    [change.address, tags.env]
  )
}

# ─────────────────────────────────────────────────────────────────────────────
# RULE 4 — Security Group: No SSH (22) open to 0.0.0.0/0
# ─────────────────────────────────────────────────────────────────────────────

deny[msg] {
  change := resource_changes[_]
  change.type == "aws_security_group_rule"
  change.change.after.type == "ingress"
  change.change.after.from_port <= 22
  change.change.after.to_port >= 22
  "0.0.0.0/0" in change.change.after.cidr_blocks
  msg := sprintf(
    "DENY [SSH-OPEN] aws_security_group_rule '%s': SSH (port 22) must not be open to 0.0.0.0/0",
    [change.address]
  )
}

# ─────────────────────────────────────────────────────────────────────────────
# RULE 5 — S3: Public access block must be fully enabled
# ─────────────────────────────────────────────────────────────────────────────

deny[msg] {
  change := resource_changes[_]
  change.type == "aws_s3_bucket_public_access_block"
  after := change.change.after
  not all_public_access_blocked(after)
  msg := sprintf(
    "DENY [S3-PUBLIC-BLOCK] aws_s3_bucket_public_access_block '%s': all four public-access-block settings must be true",
    [change.address]
  )
}

all_public_access_blocked(after) {
  after.block_public_acls       == true
  after.block_public_policy     == true
  after.ignore_public_acls      == true
  after.restrict_public_buckets == true
}

# ─────────────────────────────────────────────────────────────────────────────
# RULE 6 — S3: force_destroy must not be true in nonprod or prod
# ─────────────────────────────────────────────────────────────────────────────

deny[msg] {
  change := resource_changes[_]
  change.type == "aws_s3_bucket"
  change.change.after.force_destroy == true
  tags := change.change.after.tags
  tags.env in {"nonprod", "prod"}
  msg := sprintf(
    "DENY [S3-FORCE-DESTROY] aws_s3_bucket '%s': force_destroy must be false in env '%s'",
    [change.address, tags.env]
  )
}

# ─────────────────────────────────────────────────────────────────────────────
# RULE 7 — All resources: managed-by = terraform tag required
# ─────────────────────────────────────────────────────────────────────────────

deny[msg] {
  change := resource_changes[_]
  tags := change.change.after.tags
  not tags["managed-by"] == "terraform"
  msg := sprintf(
    "DENY [TAGGING] '%s': tag 'managed-by=terraform' is required on all resources",
    [change.address]
  )
}

# ─────────────────────────────────────────────────────────────────────────────
# RULE 8 — All resources: env tag required
# ─────────────────────────────────────────────────────────────────────────────

deny[msg] {
  change := resource_changes[_]
  tags := change.change.after.tags
  not tags["env"]
  msg := sprintf(
    "DENY [TAGGING] '%s': tag 'env' is required on all resources",
    [change.address]
  )
}
