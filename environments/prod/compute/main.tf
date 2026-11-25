# environments/prod/compute/main.tf
# Pipeline only runs this from a release-* tag with CAB approval.

module "ec2" {
  source = "../../../modules/aws/ec2"

  org         = var.org
  app         = var.app
  environment = "prod"
  region      = var.region

  subnet_id            = var.subnet_id
  vpc_id               = var.vpc_id
  instance_type        = var.instance_type # m5.large or as sized
  associate_public_ip  = false
  ami_id               = var.ami_id # PINNED in prod — no auto-latest
  ebs_encrypted        = true
  ebs_kms_key_id       = var.ebs_kms_key_arn
  iam_instance_profile = var.instance_profile
  monitoring           = true

  ingress_rules = [
    {
      description = "Allow HTTPS from VPC"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
  ]

  extra_tags = {
    cost-centre = "engineering"
    data-class  = "confidential"
  }
}

module "s3" {
  source = "../../../modules/aws/s3"

  org           = var.org
  app           = var.app
  environment   = "prod"
  region        = var.region
  bucket_suffix = var.bucket_suffix
  purpose       = "artifacts"

  force_destroy     = false # policy hard-blocks true in prod
  enable_versioning = true
  encryption_type   = "aws:kms"
  kms_key_id        = var.s3_kms_key_arn

  enable_access_logging = true
  access_log_bucket     = var.access_log_bucket

  lifecycle_rules = [
    {
      id      = "prod-tiering"
      enabled = true
      prefix  = "builds/"
      transitions = [
        { days = 30, storage_class = "STANDARD_IA" },
        { days = 90, storage_class = "GLACIER" },
      ]
      expiration_days = 365
    }
  ]

  extra_tags = {
    cost-centre = "engineering"
    data-class  = "confidential"
  }
}
