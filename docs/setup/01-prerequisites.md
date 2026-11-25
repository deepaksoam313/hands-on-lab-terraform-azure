# 01 — Prerequisites

Before you configure anything in Azure DevOps or AWS, you need these in place.

---

## Accounts

| What | Why |
|------|-----|
| AWS account | Where EC2, S3, IAM roles, and Terraform state live |
| Azure DevOps account | Where the pipeline, environments, and variable groups live |
| Git installed locally | To push code and create release tags |
| Terraform 1.9.x installed locally | To run the bootstrap |
| AWS CLI installed locally | To run the bootstrap with your personal credentials |

Sign up for Azure DevOps free at: https://dev.azure.com

---

## Information you need to collect

Write these down before starting — you will need them in later steps.

| Value | Where to find it | Example |
|-------|-----------------|---------|
| AWS Account ID | AWS Console → top right menu | `123456789012` |
| Account ID last-4 (suffix) | Last 4 digits of account ID | `9012` |
| AWS region | Where you want resources | `us-east-1` |
| Azure DevOps org name | URL: dev.azure.com/**orgname** | `mycompany` |
| Azure DevOps project name | URL: dev.azure.com/org/**project** | `iac-platform` |
| Existing VPC ID (nonprod) | AWS Console → VPC | `vpc-0abc12345` |
| Existing Subnet ID (nonprod) | AWS Console → VPC → Subnets | `subnet-0abc12345` |
| Existing VPC ID (prod) | AWS Console → VPC | `vpc-0xyz98765` |
| Existing Subnet ID (prod) | AWS Console → VPC → Subnets | `subnet-0xyz98765` |

> **No existing VPC?** You can create one manually in the AWS Console
> (VPC → Create VPC → VPC and more → default settings) or ask to add a VPC
> Terraform module to this repo.

---

## Local tools — quick install

```bash
# Terraform
curl -fsSL https://releases.hashicorp.com/terraform/1.9.5/terraform_1.9.5_linux_amd64.zip \
  -o /tmp/tf.zip && unzip /tmp/tf.zip -d /tmp && sudo mv /tmp/terraform /usr/local/bin/
terraform version

# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip /tmp/awscliv2.zip -d /tmp && sudo /tmp/aws/install
aws --version

# Configure AWS CLI with your personal credentials (for bootstrap only)
aws configure
# AWS Access Key ID: <your key>
# AWS Secret Access Key: <your secret>
# Default region: us-east-1
```
