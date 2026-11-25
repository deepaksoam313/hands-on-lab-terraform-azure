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

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "m5.large"
}

variable "ami_id" {
  type        = string
  description = "Pinned AMI ID — mandatory in prod."
}

variable "instance_profile" {
  type = string
}

variable "ebs_kms_key_arn" {
  type = string
}

variable "bucket_suffix" {
  type = string
}

variable "s3_kms_key_arn" {
  type = string
}

variable "access_log_bucket" {
  type = string
}
