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
