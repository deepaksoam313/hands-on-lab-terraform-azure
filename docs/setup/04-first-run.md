# 04 — First Run (nonprod → prod)

---

## Run 1: Nonprod deploy (merge to main)

This is the normal development flow. Every merge to `main` deploys to nonprod.
Prod stages are automatically skipped because there is no release tag.

### Trigger it

```bash
cd /home/ubuntu/hands-on-lab

# Make a small change so there is something to deploy
# (or just push as-is — first run will create the resources)
git push origin main
```

### What you will see in Azure DevOps

```
Pipeline run triggered by: push to main

Stage: CI                    ← runs immediately
  job: fmt          ✓
  job: validate     ✓
  job: lint         ✓
  job: tfsec        ✓
  job: checkov      ✓
  job: docs         ✓

Stage: PlanNonprod           ← runs after CI passes
  terraform init
  terraform plan -detailed-exitcode
  plan artifact published: plan-nonprod-compute-<buildId>

Stage: PolicyNonprod         ← OPA/conftest on plan.json
  conftest test ... ✓

Stage: ApplyNonprod          ← WAITING FOR APPROVAL
  ⏳ Waiting for approval from [platform team]
```

### Approve nonprod

```
Click the pipeline run
  → Stage: ApplyNonprod → Review
  → Download artifact: plan-nonprod-compute-<buildId>
  → Open plan.txt — review every resource change
  → Click Approve
```

```
Stage: ApplyNonprod
  terraform init
  terraform apply (saved plan)   ← applies the plan you just reviewed
  terraform output -json
  evidence artifact published

Stage: PlanProd    — SKIPPED  (Build.SourceBranch = refs/heads/main, not a release tag)
Stage: PolicyProd  — SKIPPED
Stage: ApplyProd   — SKIPPED

Stage: Evidence    ✓  (nonprod outputs captured)
```

### Verify in AWS

```
AWS Console → EC2 → Instances
  → Should see: acme-platform-nonprod-use1-ec2  (running)

AWS Console → S3
  → Should see: acme-platform-nonprod-use1-artifacts-9012
```

---

## Run 2: Prod deploy (create a release tag)

You do this when you are ready to promote nonprod to prod.
The convention is: test it in nonprod first, then tag.

### Create the release tag

```bash
# Make sure you are on the commit you want to release
git checkout main
git pull

# Create an annotated tag
git tag -a release-1.0.0 -m "Release 1.0.0 — initial EC2 + S3 compute component"

# Push the tag
git push origin release-1.0.0
```

### What you will see in Azure DevOps

```
Pipeline run triggered by: tag release-1.0.0

Stage: CI                    ✓  (same quality gates)

Stage: PlanNonprod           ✓  (nonprod plan — may show No changes if already deployed)
Stage: PolicyNonprod         ✓
Stage: ApplyNonprod          ← Waiting for approval (runs again from this tag's code)

[approve nonprod]

Stage: PlanProd              ← NOW RUNS  (source ref = refs/tags/release-1.0.0)
  terraform plan
  plan artifact published: plan-prod-compute-<buildId>

Stage: PolicyProd            ✓

Stage: ApplyProd             ← TWO CHECKS MUST PASS
  ⏳ Check 1: Branch control
     "Is ref refs/tags/release-1.0.0 matching refs/tags/release-*?"  → YES ✓
  ⏳ Check 2: Waiting for approval from [CAB group]
```

### Approve prod

```
Click the pipeline run
  → Stage: ApplyProd → Review
  → Download artifact: plan-prod-compute-<buildId>
  → Open plan.txt — review every resource that will be created/changed/destroyed
  → If the plan matches the expected scope: Approve
  → If anything looks unexpected: Reject (do not deploy)
```

```
Stage: ApplyProd
  terraform init
  terraform apply (saved plan)   ← the EXACT plan the approver reviewed
  terraform output -json
  evidence artifact published

Stage: Evidence    ✓
  Release record printed:
    Pipeline, Build ID, Source ref, Triggered by, Date (UTC)
    Nonprod outputs
    Prod outputs
    Plan summaries
```

### Verify in AWS

```
AWS Console → EC2 → Instances
  → acme-platform-prod-use1-ec2  (running)

AWS Console → S3
  → acme-platform-prod-use1-artifacts-9012
```

---

## What happens if you try to run prod without a tag

```bash
# Someone tries to deploy prod directly from main (no tag)
git push origin main
```

```
Stage: CI          ✓
Stage: PlanNonprod ✓
Stage: ApplyNonprod ✓

Stage: PlanProd    — SKIPPED
  Reason: condition evaluated to false
  Build.SourceBranch = refs/heads/main
  does not match refs/tags/release-*
```

Prod never runs. No human needed to block it — the pipeline condition blocked it.

```bash
# Someone edits the YAML, removes the condition, pushes to main
# Pipeline runs... reaches ApplyProd stage...
```

```
Stage: ApplyProd   — REJECTED by ADO Environment check
  Branch control: refs/heads/main does not match refs/tags/release-*
  Deployment rejected at platform level.
```

The second wall (ADO Environment branch control) catches what the YAML condition cannot.
