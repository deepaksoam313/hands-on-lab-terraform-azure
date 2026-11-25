# Runbook — Deploy and Rollback: EC2 + S3 (compute component)

## Normal deploy flow

1. Raise a PR against `main`. CI runs (fmt, validate, lint, Checkov).
2. PR merged to `main` → pipeline triggers.
3. **Plan stage** runs; plan artifact is published (plan-\<buildId>).
4. Approver reviews `plan.txt` in the pipeline artifact — not the console, the actual file.
5. OPA/conftest policy check passes (or fails with a named rule violation).
6. **Approval gate** (on ADO Environment) is approved by the right group.
7. **Apply stage** downloads the saved `tfplan` and applies it. No re-plan.
8. **Evidence stage** captures outputs + plan summary as a release record artifact.

---

## If the plan stage fails

| Symptom | Action |
|---------|--------|
| `fmt -check` fails | Run `terraform fmt -recursive` locally, commit the diff |
| `validate` fails | Fix the HCL error shown; re-push |
| Checkov HIGH/CRITICAL | Read the check ID, fix the resource attribute, re-push |
| OPA deny | Read the deny message in the conftest output; fix the variable or module call |
| `init` fails (backend) | Verify the Key Vault variable group has correct bucket/table values |

---

## If apply fails mid-way (partial apply)

**Do NOT blindly retry.** Terraform state is consistent up to the last successful resource.

1. Open the pipeline logs and find the first `Error:` line.
2. Run `terraform state list` (locally with the prod role, or via a break-glass pipeline job)
   to see what was created.
3. Run `terraform plan` to see exactly what remains — Terraform will only show the delta.
4. Fix the root cause (IAM permission? Resource limit? API timeout?).
5. Re-run the pipeline from the Plan stage. The apply will complete the remaining resources.

**Never run `terraform destroy` to "start clean" in nonprod or prod without a CAB ticket.**

---

## Rollback: revert a bad apply

Terraform does not have a built-in rollback. The pattern:

### Option A — Revert the commit, re-deploy (preferred)

```bash
git revert <merge-commit-sha>
git push origin main
# Pipeline triggers; plan shows the reverting diff; approve and apply.
```

### Option B — Targeted resource import/taint (surgical)

```bash
# If a single resource is broken:
terraform taint module.ec2.aws_instance.this
# Then re-run the pipeline — plan will show destroy+create for that resource only.
```

### Option C — State surgery (last resort, prod only with CAB)

```bash
# Remove a resource from state (leaves the cloud resource in place, unmanaged):
terraform state rm module.s3.aws_s3_bucket.this
# Then re-import it under a corrected address:
terraform import module.s3.aws_s3_bucket.this <bucket-name>
```

---

## Drift response

A nightly drift job runs `terraform plan -detailed-exitcode`.

| Exit code | Meaning | Action |
|-----------|---------|--------|
| 0 | No drift | No action |
| 2 | Drift detected | Triage: out-of-band change? → revert or import. Intentional? → `ignore_changes` + ADR |
| 1 | Plan error | Treat as pipeline failure; investigate provider creds / state lock |

**Decision record for ignore_changes:**  
Any `ignore_changes` addition must reference an ADR number in a comment. Example:
```hcl
lifecycle {
  ignore_changes = [tags["last-deployed"]]  # ADR-042: deployment tooling stamps this tag
}
```

---

## Break-glass access (prod emergency)

1. Raise an emergency change ticket in ServiceNow.
2. Request time-bound membership in the `tf-prod-breakglass` AAD group via PIM.
3. All actions are logged to the security channel automatically.
4. Run `terraform` from the designated jump box; state is locked for the duration.
5. After the incident, raise a PR to bring the IaC back in sync with any manual changes.
