output "ec2_instance_id" {
  description = "Sandbox EC2 instance ID."
  value       = module.ec2.instance_id
}

output "ec2_private_ip" {
  description = "Sandbox EC2 private IP."
  value       = module.ec2.private_ip
}

output "s3_bucket_id" {
  description = "Sandbox S3 bucket name."
  value       = module.s3.bucket_id
}

output "s3_bucket_arn" {
  description = "Sandbox S3 bucket ARN."
  value       = module.s3.bucket_arn
}
