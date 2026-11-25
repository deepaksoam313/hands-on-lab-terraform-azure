terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  backend "s3" {
    # Values injected at init time from backend.hcl — do NOT hard-code here.
    # terraform init -backend-config=backend.hcl
  }
}

provider "aws" {
  region = var.region

  # Auth: in the pipeline, OIDC AssumeRole via the service connection.
  # Locally: AWS_PROFILE or AWS SSO.

  default_tags {
    tags = {
      org        = var.org
      app        = var.app
      env        = "sandbox"
      managed-by = "terraform"
    }
  }
}
