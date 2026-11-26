# Module: aws/s3

Provisions a hardened S3 bucket with:
- All public access blocked
- Versioning enabled by default
- SSE-KMS encryption by default (with bucket-key to cut KMS API costs)
- TLS-only bucket policy (DenyNonTLS statement always applied)
- Optional server access logging and lifecycle rules

## Usage

```hcl
module "artifacts" {
  source = "../../modules/aws/s3"

  org           = "acme"
  app           = "platform"
  environment   = "nonprod"
  region        = "us-east-1"
  bucket_suffix = "7f3a"      # last-4 of account ID or random token
  purpose       = "artifacts"

  lifecycle_rules = [
    {
      id              = "expire-old-builds"
      enabled         = true
      prefix          = "builds/"
      transitions     = [{ days = 30, storage_class = "STANDARD_IA" }]
      expiration_days = 90
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
| bucket_suffix | string | — | Globally-unique suffix |
| purpose | string | data | Bucket purpose label |
| force_destroy | bool | false | Allow destroy with contents |
| enable_versioning | bool | true | Enable S3 versioning |
| encryption_type | string | aws:kms | AES256 or aws:kms |
| kms_key_id | string | "" | KMS key ARN (empty = aws/s3) |
| enable_access_logging | bool | false | Send access logs |
| access_log_bucket | string | "" | Target logging bucket |
| lifecycle_rules | list(object) | [] | Lifecycle rules |
| policy_json | string | "" | Additional bucket policy JSON |
| extra_tags | map(string) | {} | Additional tags |

## Outputs

| Name | Description |
|------|-------------|
| bucket_id | Bucket name |
| bucket_arn | Bucket ARN |
| bucket_domain_name | Bucket domain |
| bucket_regional_domain_name | Regional domain |
| region | AWS region |

## Version history

| Version | Change |
|---------|--------|
| v1.0.0  | Initial release — hardened S3 bucket with KMS, versioning, TLS policy |

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
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_iam_policy_document.tls_enforce](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_log_bucket"></a> [access\_log\_bucket](#input\_access\_log\_bucket) | Target bucket for server access logs.  Required when enable\_access\_logging = true. | `string` | `""` | no |
| <a name="input_access_log_prefix"></a> [access\_log\_prefix](#input\_access\_log\_prefix) | Key prefix for access log objects. | `string` | `"s3-access-logs/"` | no |
| <a name="input_app"></a> [app](#input\_app) | Application or platform name. | `string` | n/a | yes |
| <a name="input_block_public_acls"></a> [block\_public\_acls](#input\_block\_public\_acls) | Block public ACLs. | `bool` | `true` | no |
| <a name="input_block_public_policy"></a> [block\_public\_policy](#input\_block\_public\_policy) | Block public bucket policies. | `bool` | `true` | no |
| <a name="input_bucket_suffix"></a> [bucket\_suffix](#input\_bucket\_suffix) | Short suffix appended to the generated bucket name to make it globally unique.<br>Typically the AWS account ID last-4 or a short random string.<br>Bucket name pattern: <org>-<app>-<env>-<region\_short>-<purpose>-<suffix> | `string` | n/a | yes |
| <a name="input_enable_access_logging"></a> [enable\_access\_logging](#input\_enable\_access\_logging) | Send server access logs to a designated logging bucket. | `bool` | `false` | no |
| <a name="input_enable_versioning"></a> [enable\_versioning](#input\_enable\_versioning) | Enable S3 versioning.  Should be true for state buckets and prod data. | `bool` | `true` | no |
| <a name="input_encryption_type"></a> [encryption\_type](#input\_encryption\_type) | SSE algorithm: AES256 (SSE-S3) or aws:kms (SSE-KMS). | `string` | `"aws:kms"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Deployment environment: sandbox \| nonprod \| prod | `string` | n/a | yes |
| <a name="input_extra_tags"></a> [extra\_tags](#input\_extra\_tags) | Additional tags merged onto every resource. | `map(string)` | `{}` | no |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Allow Terraform to destroy the bucket even if it contains objects.<br>Set true only for sandbox/ephemeral environments.<br>A policy check blocks force\_destroy=true in prod. | `bool` | `false` | no |
| <a name="input_ignore_public_acls"></a> [ignore\_public\_acls](#input\_ignore\_public\_acls) | Ignore existing public ACLs. | `bool` | `true` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS key ARN for SSE-KMS.  Required when encryption\_type = aws:kms.  Empty = aws/s3 managed key. | `string` | `""` | no |
| <a name="input_lifecycle_rules"></a> [lifecycle\_rules](#input\_lifecycle\_rules) | Lifecycle rules for the bucket.  Empty list = no rules. | <pre>list(object({<br>    id      = string<br>    enabled = bool<br>    prefix  = string<br>    transitions = list(object({<br>      days          = number<br>      storage_class = string<br>    }))<br>    expiration_days = number # 0 = no expiration<br>  }))</pre> | `[]` | no |
| <a name="input_org"></a> [org](#input\_org) | Organisation short-name used in the bucket name and tags. | `string` | n/a | yes |
| <a name="input_policy_json"></a> [policy\_json](#input\_policy\_json) | Optional bucket policy JSON.  Applied as-is.  Validate with conftest before use. | `string` | `""` | no |
| <a name="input_purpose"></a> [purpose](#input\_purpose) | Short label for the bucket's purpose: logs \| artifacts \| data \| backup \| state | `string` | `"data"` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region. | `string` | `"us-east-1"` | no |
| <a name="input_restrict_public_buckets"></a> [restrict\_public\_buckets](#input\_restrict\_public\_buckets) | Restrict public bucket policies. | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | The ARN of the S3 bucket. |
| <a name="output_bucket_domain_name"></a> [bucket\_domain\_name](#output\_bucket\_domain\_name) | Bucket domain name (e.g. <bucket>.s3.amazonaws.com). |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | The S3 bucket name (same as the ID). |
| <a name="output_bucket_regional_domain_name"></a> [bucket\_regional\_domain\_name](#output\_bucket\_regional\_domain\_name) | Regional bucket domain name. |
| <a name="output_region"></a> [region](#output\_region) | AWS region where the bucket lives. |
<!-- END_TF_DOCS -->