output "instance_id" {
  description = "The EC2 instance ID."
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "The EC2 instance ARN."
  value       = aws_instance.this.arn
}

output "private_ip" {
  description = "Private IP address of the instance."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP address of the instance (empty string if associate_public_ip = false)."
  value       = aws_instance.this.public_ip
}

output "security_group_id" {
  description = "Security group ID attached to the instance."
  value       = aws_security_group.this.id
}

output "ami_id" {
  description = "AMI ID used to launch the instance (resolved from the data source if auto-selected)."
  value       = local.resolved_ami
}
