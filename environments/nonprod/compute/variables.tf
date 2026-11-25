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
  default = "t3.small"
}

variable "instance_profile" {
  type    = string
  default = ""
}

variable "ebs_kms_key_arn" {
  type    = string
  default = ""
}

variable "bucket_suffix" {
  type = string
}

variable "s3_kms_key_arn" {
  type    = string
  default = ""
}

variable "access_log_bucket" {
  type    = string
  default = ""
}
