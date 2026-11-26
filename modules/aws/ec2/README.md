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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.40.0, < 6.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group_rule.egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_security_group_rule.ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_ami.al2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI ID to launch.  Leave empty to auto-select the latest Amazon Linux 2023 AMI<br>for the given region.  Pinning to an explicit AMI ID is recommended for prod to<br>avoid uncontrolled OS upgrades. | `string` | `""` | no |
| <a name="input_app"></a> [app](#input\_app) | Application or platform name. | `string` | n/a | yes |
| <a name="input_associate_public_ip"></a> [associate\_public\_ip](#input\_associate\_public\_ip) | Assign a public IP.  Should be false for prod/nonprod (private subnets). | `bool` | `false` | no |
| <a name="input_ebs_encrypted"></a> [ebs\_encrypted](#input\_ebs\_encrypted) | Encrypt the root EBS volume.  Always true in prod/nonprod via policy check. | `bool` | `true` | no |
| <a name="input_ebs_kms_key_id"></a> [ebs\_kms\_key\_id](#input\_ebs\_kms\_key\_id) | KMS key ARN for EBS encryption.  Empty = AWS-managed key (aws/ebs). | `string` | `""` | no |
| <a name="input_egress_cidr"></a> [egress\_cidr](#input\_egress\_cidr) | Egress CIDR.  Defaults to 0.0.0.0/0; restrict to VPC CIDR for high-sec workloads. | `string` | `"0.0.0.0/0"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment: sandbox \| nonprod \| prod | `string` | n/a | yes |
| <a name="input_extra_tags"></a> [extra\_tags](#input\_extra\_tags) | Additional tags merged onto every resource. | `map(string)` | `{}` | no |
| <a name="input_iam_instance_profile"></a> [iam\_instance\_profile](#input\_iam\_instance\_profile) | IAM instance profile name to attach.  Leave empty for no profile. | `string` | `""` | no |
| <a name="input_ingress_rules"></a> [ingress\_rules](#input\_ingress\_rules) | Ingress rules for the instance security group.  Default: empty (no inbound).<br>For prod, prefer VPC-internal CIDRs only; a policy check blocks 0.0.0.0/0 on SSH. | <pre>list(object({<br>    description = string<br>    from_port   = number<br>    to_port     = number<br>    protocol    = string<br>    cidr_blocks = list(string)<br>  }))</pre> | `[]` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type (e.g. t3.micro, m5.large). | `string` | `"t3.micro"` | no |
| <a name="input_key_name"></a> [key\_name](#input\_key\_name) | EC2 key-pair name for SSH access.  Leave empty to disable SSH key attachment. | `string` | `""` | no |
| <a name="input_metadata_tokens_required"></a> [metadata\_tokens\_required](#input\_metadata\_tokens\_required) | Enforce IMDSv2 (token-required).  Disabling is a Checkov HIGH finding. | `bool` | `true` | no |
| <a name="input_monitoring"></a> [monitoring](#input\_monitoring) | Enable detailed CloudWatch monitoring. | `bool` | `true` | no |
| <a name="input_org"></a> [org](#input\_org) | Organisation short-name used in every resource name and tag. | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region where resources are created. | `string` | `"us-east-1"` | no |
| <a name="input_root_volume_size_gb"></a> [root\_volume\_size\_gb](#input\_root\_volume\_size\_gb) | Root EBS volume size in GiB. | `number` | `20` | no |
| <a name="input_root_volume_type"></a> [root\_volume\_type](#input\_root\_volume\_type) | EBS volume type: gp3 (default) \| gp2 \| io1 \| io2 | `string` | `"gp3"` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | Subnet ID in which to place the instance. | `string` | n/a | yes |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | Base64-encoded user-data script.  Optional. | `string` | `""` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID used to scope the security group. | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ami_id"></a> [ami\_id](#output\_ami\_id) | AMI ID used to launch the instance (resolved from the data source if auto-selected). |
| <a name="output_instance_arn"></a> [instance\_arn](#output\_instance\_arn) | The EC2 instance ARN. |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | The EC2 instance ID. |
| <a name="output_private_ip"></a> [private\_ip](#output\_private\_ip) | Private IP address of the instance. |
| <a name="output_public_ip"></a> [public\_ip](#output\_public\_ip) | Public IP address of the instance (empty string if associate\_public\_ip = false). |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group ID attached to the instance. |
<!-- END_TF_DOCS -->