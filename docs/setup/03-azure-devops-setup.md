# 03 — Azure DevOps Setup

Configure everything in this order. Each step depends on the previous one.

---

## Step 1 — Create the project and push the repo

### Create a project
```
dev.azure.com → New project
  Name:       iac-platform
  Visibility: Private
  Version control: Git
```

### Push the code
```bash
cd /home/ubuntu/hands-on-lab

git init
git add .
git commit -m "feat: initial EC2 + S3 compute component"

# Replace ORG with your Azure DevOps org name
git remote add origin https://ORG@dev.azure.com/ORG/iac-platform/_git/iac-platform
git push -u origin main
```

---

## Step 2 — Create Variable Groups

Variable groups are where pipeline secrets live — linked to Azure Key Vault so the
values never appear in YAML or pipeline logs.

For this lab, we will create them directly (without Key Vault) to keep it simple.
In a real production setup, every secret value should come from Key Vault.

```
Azure DevOps → iac-platform project
  → Pipelines → Library → + Variable group
```

### Group 1: `tf-nonprod-vars`

| Variable | Value | Secret |
|----------|-------|--------|
| TF_STATE_BUCKET | acme-tfstate-us-east-1-9012 | No |
| TF_LOCK_TABLE | acme-tf-locks | No |
| AWS_ROLE_ARN | arn:aws:iam::123456789012:role/tf-nonprod-compute | No |
| VPC_ID | vpc-0abc12345 | No |
| SUBNET_ID | subnet-0abc12345 | No |
| BUCKET_SUFFIX | 9012 | No |

Click **Save**.

### Group 2: `tf-prod-vars`

Same variable names, different values pointing at your prod VPC and prod IAM role.

| Variable | Value | Secret |
|----------|-------|--------|
| TF_STATE_BUCKET | acme-tfstate-us-east-1-9012 | No |
| TF_LOCK_TABLE | acme-tf-locks | No |
| AWS_ROLE_ARN | arn:aws:iam::123456789012:role/tf-prod-compute | No |
| VPC_ID | vpc-0xyz98765 | No |
| SUBNET_ID | subnet-0xyz98765 | No |
| BUCKET_SUFFIX | 9012 | No |

Click **Save**.

> **Why two separate groups?**
> Each environment uses a different IAM role (least privilege) and different
> network IDs. Separating them means a nonprod pipeline run can never accidentally
> read a prod credential.

---

## Step 3 — Create the Service Connections

Service connections are how Azure DevOps authenticates to AWS using OIDC.
One connection per environment.

```
Azure DevOps → Project Settings (bottom left gear)
  → Service connections → New service connection → AWS
```

### Connection 1: `sc-aws-nonprod`

```
Connection type:  AWS
Authentication:   OpenID Connect (OIDC)
Role ARN:         arn:aws:iam::123456789012:role/tf-nonprod-compute
AWS Region:       us-east-1
Connection name:  sc-aws-nonprod
☑ Grant access permission to all pipelines
```

### Connection 2: `sc-aws-prod`

```
Role ARN:         arn:aws:iam::123456789012:role/tf-prod-compute
Connection name:  sc-aws-prod
```

> **How this works:** When the pipeline runs, Azure DevOps generates a short-lived
> OIDC token and passes it to the agent as `AWS_WEB_IDENTITY_TOKEN_FILE`. The agent
> calls `sts:AssumeRoleWithWebIdentity` to get temporary AWS credentials. No key is
> ever stored anywhere.

---

## Step 4 — Create the ADO Environments

Environments are where approval gates and branch controls live.
They are separate from the pipeline YAML — this is intentional.

```
Azure DevOps → Pipelines → Environments → New environment
```

Create both:

```
Name:     nonprod.compute
Resource: None
```

```
Name:     prod.compute
Resource: None
```

---

## Step 5 — Configure checks on `nonprod.compute`

```
Pipelines → Environments → nonprod.compute
  → ⋯ (three-dot menu, top right) → Approvals and checks → + Add check
```

### Add: Approval

```
Type:         Approvals
Approvers:    [your Azure DevOps user, or your platform team group]
Instructions: Review the plan artifact plan-nonprod-compute-<buildId>
              in the pipeline artifacts before approving.
Timeout:      24 hours
```

Click **Create**.

---

## Step 6 — Configure checks on `prod.compute`

This is the most important configuration step.
You are adding **two independent checks** — both must pass before prod deploys.

```
Pipelines → Environments → prod.compute
  → ⋯ → Approvals and checks → + Add check
```

### Check 1: Approval

```
Type:         Approvals
Approvers:    [your CAB group or senior engineer]
Instructions: 1. Download the plan artifact (plan-prod-compute-<buildId>).
              2. Open plan.txt and review every resource change.
              3. Verify a change ticket exists for this release.
              4. Only approve if the plan matches the ticket scope.
Timeout:      24 hours
```

### Check 2: Branch control

```
+ Add check → Branch control

Allowed branches:   refs/tags/release-*
☑ Verify branch protection policies
```

Click **Save**.

**What this does:**
Even if someone runs the pipeline manually, even if someone edits the YAML and removes
the condition, the `prod.compute` environment itself will reject the deployment job
unless it is running from a Git ref that matches `refs/tags/release-*`.

The two checks together mean:
1. The pipeline must be triggered by a `release-*` tag (branch control)
2. A human must review and approve the plan (approval gate)

Both are enforced by the Azure DevOps platform — not by the YAML.

---

## Step 7 — Create the pipeline

```
Azure DevOps → Pipelines → New pipeline
  → Where is your code? → Azure Repos Git
  → Select repository: iac-platform
  → Configure: Existing Azure Pipelines YAML file
  → Branch: main
  → Path: /pipelines/terraform-cd.yml
  → Continue → Save (do not run yet)
```

Rename the pipeline if you want:
```
⋯ → Rename/move → iac-platform-compute-cd
```

---

## Step 8 — Verify the pipeline YAML is linked to variable groups

The pipeline YAML references variable groups by name:
```yaml
- group: tf-nonprod-vars
- group: tf-prod-vars
```

Azure DevOps will ask you to authorize the pipeline to use these groups the first time
it runs. Click **Permit** when prompted.

---

## Summary — what you have configured

```
Azure DevOps
├── Repo:           iac-platform  (your Terraform code)
├── Variable groups
│   ├── tf-nonprod-vars  (nonprod AWS config — no secrets in YAML)
│   └── tf-prod-vars     (prod AWS config)
├── Service connections
│   ├── sc-aws-nonprod   (OIDC → tf-nonprod-compute IAM role)
│   └── sc-aws-prod      (OIDC → tf-prod-compute IAM role)
├── Environments
│   ├── nonprod.compute
│   │   └── Check: Approval (platform team)
│   └── prod.compute
│       ├── Check: Approval (CAB group)
│       └── Check: Branch control (refs/tags/release-*)
└── Pipeline: iac-platform-compute-cd
    └── File: pipelines/terraform-cd.yml
```
