# Security Model

How credentials, secrets, and access are handled across the pipeline.

---

## No long-lived AWS credentials anywhere

```
Traditional (bad):
  IAM user → access key → stored in ADO variable group → used in every pipeline run
  Problem: key never expires, one leak = full account access until someone notices

This pipeline (good):
  OIDC trust → pipeline gets a short-lived token → exchanges for 1-hour AWS creds
  Problem to solve if key leaks: there is no key to leak
```

The flow per pipeline run:

```
1. ADO agent starts
2. Azure DevOps generates an OIDC JWT for this specific run
   (contains: org, project, pipeline ID, run ID — expires in minutes)
3. Agent calls AWS STS AssumeRoleWithWebIdentity
   passing: role ARN + JWT
4. AWS verifies:
   - JWT signature matches the OIDC provider thumbprint
   - aud claim = api://AzureADTokenExchange
   - sub claim matches sc://org/project/* pattern on the role trust policy
5. AWS returns temporary credentials (AccessKeyId, SecretAccessKey, SessionToken)
   valid for 1 hour
6. Terraform uses those credentials
7. Run ends — credentials expired, nothing to rotate or revoke
```

---

## Least privilege per environment

Each environment has its own IAM role with the minimum permissions needed.

| Role | Permissions | Cannot do |
|------|-------------|-----------|
| tf-nonprod-compute | EC2/S3/KMS in nonprod, state bucket R/W | Touch prod resources |
| tf-prod-compute | EC2/S3/KMS in prod, state bucket R/W | Touch nonprod resources |

If the nonprod pipeline is compromised, it cannot affect prod — wrong role, wrong
state key, wrong VPC.

---

## Secrets never in YAML or repo

| What | Where it lives | How pipeline accesses it |
|------|---------------|--------------------------|
| AWS role ARN | ADO variable group | `$(AWS_ROLE_ARN)` at runtime |
| VPC/subnet IDs | ADO variable group | `$(VPC_ID)` at runtime |
| State bucket name | ADO variable group | `$(TF_STATE_BUCKET)` at runtime |
| Future: DB passwords | AWS Secrets Manager | Terraform creates the container, app reads the value directly |
| Future: TLS certs | AWS ACM | Referenced by ARN, never in state |

The `.gitignore` blocks `backend.hcl` and `*.tfvars` from being committed.
The pipeline generates these files at runtime from variable group values.

---

## Terraform state security

State files contain sensitive data (resource IDs, sometimes outputs marked sensitive).

| Control | Implementation |
|---------|----------------|
| Encryption at rest | S3 SSE-KMS (bucket enforces it) |
| Encryption in transit | Bucket policy DenyNonTLS (rejects HTTP requests) |
| Access control | Only the pipeline IAM roles have S3:GetObject/PutObject on the state bucket |
| Versioning | S3 versioning enabled — previous state versions are recoverable |
| Locking | DynamoDB table prevents concurrent applies |
| Audit | S3 server access logs capture every read/write |

---

## Two-layer policy enforcement

```
Layer 1 — Static (CI stage)
  tfsec + Checkov scan the HCL source
  Catches: hardcoded misconfigurations, known bad patterns
  Limitation: sees variable references, not resolved values

Layer 2 — Runtime (PolicyNonprod / PolicyProd stages)
  conftest scans plan.json (terraform show -json tfplan)
  Catches: misconfigurations after variable substitution
  Example: encrypted = var.flag where flag resolves to false at runtime
```

A finding in either layer blocks the pipeline. The exception process requires a
documented waiver with a ticket number — not a code comment.

---

## What an auditor sees

After every prod deploy, the Evidence stage publishes:

```
evidence-prod-compute-<buildId>/
  outputs.json     — terraform output -json (instance IDs, bucket ARNs)
  plan.txt         — human-readable plan showing every change
```

The pipeline run log shows:
- Who triggered it (Build.RequestedFor)
- What ref it ran from (Build.SourceBranch = refs/tags/release-1.0.0)
- Who approved it (ADO Environment approval history)
- When it ran (timestamp)

This satisfies a typical SOC2 or ISO27001 change-management audit without anyone
taking manual screenshots.
