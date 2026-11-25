# Documentation Index

## Setup — do these in order

| Doc | What it covers |
|-----|---------------|
| [01-prerequisites.md](setup/01-prerequisites.md) | Accounts, tools, and values to collect before starting |
| [02-bootstrap-aws.md](setup/02-bootstrap-aws.md) | Create S3 state bucket, DynamoDB lock table, OIDC IAM roles |
| [03-azure-devops-setup.md](setup/03-azure-devops-setup.md) | Variable groups, service connections, environments, pipeline |
| [04-first-run.md](setup/04-first-run.md) | Running nonprod and prod deploys end-to-end, what to expect |

## Architecture — understand the design

| Doc | What it covers |
|-----|---------------|
| [pipeline-design.md](architecture/pipeline-design.md) | Why the pipeline is structured the way it is, key decisions |
| [security-model.md](architecture/security-model.md) | OIDC auth, least privilege, secrets handling, audit trail |

## Pipeline reference

| Doc | What it covers |
|-----|---------------|
| [ci-gates.md](pipeline/ci-gates.md) | What each CI job checks, how to fix failures |
| [branch-and-tag-strategy.md](pipeline/branch-and-tag-strategy.md) | Branch model, tag convention, hotfix flow |

## Runbooks — operational procedures

| Doc | What it covers |
|-----|---------------|
| [deploy-and-rollback.md](runbooks/deploy-and-rollback.md) | Normal deploy, partial apply recovery, rollback options, drift response |
