# environments/nonprod/compute/main.tf

module "ec2" {
  source = "../../../modules/aws/ec2"

  org         = var.org
  app         = var.app
  environment = "nonprod"
  region      = var.region

  subnet_id            = var.subnet_id
  vpc_id               = var.vpc_id
  instance_type        = var.instance_type # typically t3.small for nonprod
  associate_public_ip  = false
  ebs_encrypted        = true
  ebs_kms_key_id       = var.ebs_kms_key_arn # customer-managed key
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
    data-class  = "internal"
  }
}

module "s3" {
  source = "../../../modules/aws/s3"

  org           = var.org
  app           = var.app
  environment   = "nonprod"
  region        = var.region
  bucket_suffix = var.bucket_suffix
  purpose       = "artifacts"

  force_destroy     = false # policy check blocks true in nonprod+
  enable_versioning = true
  encryption_type   = "aws:kms"
  kms_key_id        = var.s3_kms_key_arn

  enable_access_logging = true
  access_log_bucket     = var.access_log_bucket

  lifecycle_rules = [
    {
      id              = "transition-to-ia"
      enabled         = true
      prefix          = "builds/"
      transitions     = [{ days = 30, storage_class = "STANDARD_IA" }]
      expiration_days = 180
    }
  ]

  extra_tags = {
    cost-centre = "engineering"
    data-class  = "internal"
  }
}
