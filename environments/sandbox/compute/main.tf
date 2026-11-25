# environments/sandbox/compute/main.tf
# ── Thin wiring layer: no resource blocks, only module calls ──────────────────

module "ec2" {
  source = "../../../modules/aws/ec2"

  org         = var.org
  app         = var.app
  environment = "sandbox"
  region      = var.region

  subnet_id           = var.subnet_id
  vpc_id              = var.vpc_id
  instance_type       = var.instance_type
  associate_public_ip = false # instances stay private even in sandbox
  ebs_encrypted       = true  # policy check will block false
  monitoring          = false # save cost in sandbox; policy check allows this for sandbox

  ingress_rules = [
    {
      description = "Allow HTTPS from VPC CIDR"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
  ]

  extra_tags = { cost-centre = "engineering" }
}

module "s3" {
  source = "../../../modules/aws/s3"

  org           = var.org
  app           = var.app
  environment   = "sandbox"
  region        = var.region
  bucket_suffix = var.bucket_suffix
  purpose       = "artifacts"

  # Sandbox: allow force_destroy so ephemeral environments can be torn down cleanly.
  force_destroy     = true
  enable_versioning = false    # not needed for ephemeral sandbox
  encryption_type   = "AES256" # SSE-S3 is fine for sandbox; KMS not required

  lifecycle_rules = [
    {
      id              = "expire-sandbox-objects"
      enabled         = true
      prefix          = ""
      transitions     = []
      expiration_days = 30 # auto-delete everything after 30 days
    }
  ]

  extra_tags = { cost-centre = "engineering" }
}
