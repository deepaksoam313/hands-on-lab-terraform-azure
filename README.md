# iac-platform — Hands-On Lab

Provisions an EC2 instance and S3 bucket on AWS using the full production pattern:
reusable Terraform modules → environment wiring → Azure DevOps pipeline with plan,
policy check, approval gate, apply, and evidence capture.

## Repo layout

```
iac-platform/
├── modules/
│   └── aws/
│       ├── ec2/          # reusable EC2 module (v1.0.0)
│       └── s3/           # reusable S3 module  (v1.0.0)
├── environments/
│   ├── sandbox/compute/  # sandbox wiring (no approval gate, auto-apply)
│   ├── nonprod/compute/  # nonprod wiring (platform-team approval)
│   └── prod/compute/     # prod wiring (CAB approval, release tag only)
├── policies/             # OPA/conftest policy rules
├── pipelines/            # Azure DevOps YAML
└── docs/runbooks/        # deploy + rollback runbook
```

## Running locally (sandbox)

```bash
cd environments/sandbox/compute
cp backend.hcl.example backend.hcl      # fill in your S3 bucket + DynamoDB table
cp sandbox.tfvars.example sandbox.tfvars

terraform init -backend-config=backend.hcl
terraform plan  -var-file=sandbox.tfvars -out=tfplan
terraform apply tfplan
```

## Pipeline

See `pipelines/terraform-cd.yml`. The pipeline is parameterised on `environment`
(`sandbox` / `nonprod` / `prod`) and `component` (here: `compute`).
