terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  backend "s3" {
    # Injected by pipeline: -backend-config=backend.hcl
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      org        = var.org
      app        = var.app
      env        = "nonprod"
      managed-by = "terraform"
    }
  }
}
