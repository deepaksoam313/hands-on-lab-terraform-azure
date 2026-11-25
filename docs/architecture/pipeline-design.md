# Pipeline Design — Decisions and Rationale

This document explains why the pipeline is built the way it is.
Useful for onboarding, interviews, and architecture reviews.

---

## Overall flow

```
PR to main
  └─ CI only  (6 parallel quality gates, no cloud access)
       fmt / validate / lint / tfsec / checkov / terraform-docs

Merge to main
  └─ CI
  └─ PlanNonprod  →  PolicyNonprod  →  ApplyNonprod [approval]
  └─ PlanProd, PolicyProd, ApplyProd [approval + branch control]  — SKIPPED (no tag)
  └─ Evidence

Push release-* tag
  └─ CI
  └─ PlanNonprod  →  PolicyNonprod  →  ApplyNonprod [approval]
  └─ PlanProd     →  PolicyProd     →  ApplyProd [approval + branch control]
  └─ Evidence

Nightly schedule
  └─ DriftCheck (nonprod + prod in parallel)
```

---

## Decision: separate nonprod and prod stages (not a parameter)

**What was rejected:** A single Apply stage with an `environment` parameter that a
human selects before running.

**Why rejected:**
- Nothing prevents a person from selecting `prod` and skipping nonprod.
- The pipeline has no memory of whether nonprod succeeded.
- A parameter is a UI choice, not a policy.

**What we use instead:** Hardwired sequential stages with `dependsOn`.

```yaml
- stage: ApplyProd
  dependsOn: ApplyNonprod     # prod cannot start unless nonprod succeeded
```

The pipeline itself enforces the promotion order. No human decision required.

---

## Decision: CI gates are parallel jobs (not sequential steps)

**Why:** Fail fast, fail clearly.

If you run fmt → validate → lint → tfsec → checkov in sequence, a checkov failure
takes 4 minutes to surface because you waited for the previous steps.
Running them in parallel means all failures surface at the same time — the developer
sees the full picture in one pass.

Each job also fails independently with its own clear name in the pipeline UI:
`fmt ✗` is immediately obvious. `CI ✗` with 6 steps mixed together is not.

---

## Decision: save tfplan and apply the saved plan

```yaml
terraform plan -out=tfplan          # Stage: Plan
terraform apply tfplan              # Stage: Apply (downloads the same artifact)
```

**Why this matters:**

`terraform apply` with no arguments runs a fresh plan internally before applying.
That means the approver reviewed plan X but Terraform actually applied plan Y
(if any state or external resource changed between Plan and Apply).

Saving `-out=tfplan` and applying that file guarantees:
- What the approver saw is exactly what runs.
- The plan → apply pair is atomic. No drift window.

This is the single detail that most distinguishes "someone who has run Terraform" from
"someone who runs Terraform pipelines in production."

---

## Decision: two layers of security scanning (tfsec + Checkov)

Both scan static HCL, but they have different rule sets and different coverage.

| Tool | Strength | Example rules |
|------|----------|---------------|
| tfsec | AWS/GCP/Azure deep rules, SARIF output for Advanced Security | CKV_AWS_8 (IMDSv2), CKV_AWS_79 (EBS encryption) |
| Checkov | Broader framework coverage, JUnit for test results dashboard | CKV_AWS_20 (S3 public), CKV_AWS_119 (DynamoDB encryption) |

Running both means a rule gap in one tool is caught by the other.
Both are set to hard-fail on HIGH and CRITICAL — MEDIUM and LOW are reported but
do not block the pipeline (they can be reviewed and triaged separately).

---

## Decision: OPA/conftest on plan.json (not just static HCL)

tfsec and Checkov scan the HCL source — they see what you wrote.
conftest scans `terraform show -json tfplan` — it sees what Terraform resolved.

**Why the difference matters:**

```hcl
# HCL source
variable "ebs_encrypted" { default = true }

resource "aws_instance" "this" {
  root_block_device {
    encrypted = var.ebs_encrypted   # static scanner sees a variable reference
  }
}
```

A static scanner sees `var.ebs_encrypted` — it cannot know the final value.
conftest on the plan JSON sees `"encrypted": false` — the actual resolved value
after all variable substitution.

This catches misconfigurations that static analysis cannot.

---

## Decision: approval gate on the ADO Environment, not in YAML

**Wrong way:**
```yaml
- stage: ApplyProd
  jobs:
  - job: waitForApproval
    steps:
    - task: ManualValidation@0    # ← approval in YAML
```

**Why wrong:** Anyone who can edit the YAML can remove the approval step.

**Right way:**
```yaml
  environment: prod.compute       # ← approval defined on the Environment, not here
```

The approval is configured in `Azure DevOps → Pipelines → Environments → prod.compute →
Approvals and checks`. This requires ADO admin access to change — a completely different
permission from repo write access.

---

## Decision: branch control as a second enforcement layer

The YAML condition:
```yaml
condition: startsWith(variables['Build.SourceBranch'], 'refs/tags/release-')
```
...can be bypassed by editing the YAML.

The ADO Environment branch control check cannot be bypassed by editing the YAML.
It is enforced by the Azure DevOps platform before the deployment job starts.

Together:
- YAML condition blocks automated triggers from non-tag refs
- Branch control blocks manual runs, YAML edits, and anything else

---

## Decision: nightly drift detection as a separate stage

Drift = real infrastructure diverged from the Terraform state.
Causes: manual console changes, auto-remediation tools, expired resources, etc.

A nightly `terraform plan -detailed-exitcode` per environment surfaces drift before
it becomes a problem. Exit code 2 means changes are present (drift). The job warns
and would open a ServiceNow ticket in a production setup.

The drift stage has `dependsOn: []` — it is completely independent of the deploy
stages. It runs even if the deploy stages were skipped (e.g. on the nightly schedule
when there is no push).

---

## Trigger summary

| Event | What runs |
|-------|-----------|
| PR to main | CI only |
| Push to main | CI → nonprod pipeline (prod stages skipped) |
| Push `release-*` tag | CI → nonprod → prod pipeline |
| Nightly schedule | DriftCheck (nonprod + prod) |
| Manual run | Whatever stages pass the conditions and environment checks |
