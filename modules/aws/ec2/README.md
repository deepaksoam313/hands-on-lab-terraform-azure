# Module: aws/ec2

Provisions a single EC2 instance with an attached security group.

**Security defaults (enforced by module + policy checks):**
- IMDSv2 tokens required (blocks SSRF metadata theft)
- EBS root volume encrypted (`ebs_encrypted = true` by default)
- No public IP by default (`associate_public_ip = false`)
- No inbound rules by default (caller must explicitly open ports)

## Usage

```hcl
module "app_server" {
  source = "../../modules/aws/ec2"

  org         = "acme"
  app         = "platform"
  environment = "nonprod"
  region      = "us-east-1"

  subnet_id     = "subnet-0abc1234"
  vpc_id        = "vpc-0abc1234"
  instance_type = "t3.micro"

  ingress_rules = [
    {
      description = "Allow HTTPS from VPC"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
  ]
}
```

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| org | string | — | Organisation short-name |
| app | string | — | Application name |
| environment | string | — | sandbox / nonprod / prod |
| region | string | us-east-1 | AWS region |
| subnet_id | string | — | Subnet to place the instance in |
| vpc_id | string | — | VPC for the security group |
| instance_type | string | t3.micro | EC2 instance type |
| ami_id | string | "" | Pin AMI; empty = latest AL2023 |
| associate_public_ip | bool | false | Assign public IP |
| key_name | string | "" | EC2 key pair name |
| root_volume_size_gb | number | 20 | Root EBS volume size |
| root_volume_type | string | gp3 | gp2 / gp3 / io1 / io2 |
| ebs_encrypted | bool | true | Encrypt root EBS |
| ebs_kms_key_id | string | "" | KMS key ARN (empty = aws/ebs) |
| iam_instance_profile | string | "" | IAM instance profile |
| monitoring | bool | true | Detailed CloudWatch monitoring |
| metadata_tokens_required | bool | true | IMDSv2 enforcement |
| ingress_rules | list(object) | [] | Security group inbound rules |
| egress_cidr | string | 0.0.0.0/0 | Security group outbound CIDR |
| extra_tags | map(string) | {} | Additional resource tags |

## Outputs

| Name | Description |
|------|-------------|
| instance_id | EC2 instance ID |
| instance_arn | EC2 instance ARN |
| private_ip | Private IP address |
| public_ip | Public IP (empty if no public IP) |
| security_group_id | Attached security group ID |
| ami_id | Resolved AMI ID used at launch |

## Version history

| Version | Change |
|---------|--------|
| v1.0.0  | Initial release — EC2 + SG, IMDSv2, EBS encryption |
