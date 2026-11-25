# 02 — Bootstrap AWS (State Bucket + IAM OIDC Roles)

This is the **one-time manual step** you run with your personal AWS credentials.
It creates the infrastructure that the pipeline itself depends on:
- S3 bucket — stores Terraform state files
- DynamoDB table — prevents two pipeline runs from applying at the same time (state locking)
- IAM OIDC provider — lets Azure DevOps prove its identity to AWS without any stored keys
- IAM roles — one per environment (nonprod, prod), each with least-privilege permissions

After this step, **no human ever touches AWS credentials again** — the pipeline uses OIDC.

---

## Why OIDC instead of access keys?

The traditional way is to create an IAM user, generate an access key, and store it in
Azure DevOps as a secret. The problem:

- The key is a long-lived credential — if it leaks, it works until someone rotates it
- It needs manual rotation
- Every pipeline run uses the same static key

OIDC works differently. Azure DevOps generates a **short-lived token** (valid for minutes)
for each pipeline run. AWS verifies the token against the OIDC provider and issues
temporary credentials. There is no key to store, rotate, or leak.

```
Pipeline agent runs
       │
       ▼
Azure DevOps issues a short-lived OIDC token (JWT) for this run
       │
       ▼
Pipeline calls AWS STS AssumeRoleWithWebIdentity
  passing: role ARN + OIDC token
       │
       ▼
AWS verifies token against the OIDC provider thumbprint
AWS checks the sub claim matches the allowed pattern
       │
       ▼
AWS returns temporary credentials (valid 1 hour)
       │
       ▼
Terraform uses those credentials — they expire automatically
```

---

## Run the bootstrap

```bash
cd /home/ubuntu/hands-on-lab/bootstrap

terraform init

terraform apply \
  -var="account_suffix=9012" \
  -var="ado_org_name=mycompany" \
  -var="ado_project_name=iac-platform"
```

Replace:
- `9012` → last 4 digits of your AWS account ID
- `mycompany` → your Azure DevOps org name
- `iac-platform` → your Azure DevOps project name

**Expected output:**

```
Apply complete! Resources: 6 added.

Outputs:

state_bucket_name = "acme-tfstate-us-east-1-9012"
lock_table_name   = "acme-tf-locks"
nonprod_role_arn  = "arn:aws:iam::123456789012:role/tf-nonprod-compute"
prod_role_arn     = "arn:aws:iam::123456789012:role/tf-prod-compute"
```

**Write these four values down.** You will paste them into Azure DevOps in the next step.

---

## What was created in AWS

After the bootstrap, verify in the AWS Console:

| Service | Resource | Check |
|---------|----------|-------|
| S3 | `acme-tfstate-us-east-1-9012` | Versioning = Enabled, Encryption = SSE-KMS |
| DynamoDB | `acme-tf-locks` | Table exists, hash key = LockID |
| IAM → Identity providers | `vstoken.dev.azure.com/mycompany` | Type = OpenID Connect |
| IAM → Roles | `tf-nonprod-compute` | Trust policy shows the OIDC provider |
| IAM → Roles | `tf-prod-compute` | Trust policy shows the OIDC provider |

---

## Bootstrap state file

The bootstrap itself has a local state file at `bootstrap/terraform.tfstate`.
Keep it — you need it if you ever want to modify or destroy the bootstrap resources.
Do NOT commit it to git (it is in `.gitignore`).
