# CI Gates — What Each Check Does and Why

The CI stage runs 6 jobs in parallel. Every job must pass before the pipeline
moves to the Plan stage. Here is what each one checks and what it catches.

---

## 1. fmt — terraform fmt -check

**Command:**
```bash
terraform fmt -check -recursive
```

**What it does:**
Checks that every `.tf` file in the repo is formatted according to the official
Terraform style (2-space indent, aligned `=` signs, etc.).

**Why it matters:**
Consistent formatting means diffs only show real changes — not whitespace noise.
It also enforces that no one bypasses the formatter by just pushing unformatted code.

**Fixing a failure:**
```bash
terraform fmt -recursive    # auto-fixes all files
git add -A && git commit -m "style: terraform fmt"
```

---

## 2. validate — terraform init -backend=false && validate

**Command:**
```bash
terraform init -backend=false
terraform validate
```

**What it does:**
`init -backend=false` downloads providers without connecting to a remote backend
(no cloud credentials needed). `validate` checks that the HCL is syntactically and
semantically correct — variable references, resource types, required attributes.

**Why -backend=false:**
CI agents do not have AWS credentials. Skipping the backend means validate works
with no secrets — cheaper and faster.

**What it catches:**
- Typos in resource type names (`aws_instanc` instead of `aws_instance`)
- Missing required arguments
- Type mismatches (`string` passed where `number` expected)
- Invalid variable references

**What it does NOT catch:**
- Whether the resources actually exist in AWS
- Permission errors
- Plan-time errors (those need a real `terraform plan`)

---

## 3. lint — TFLint

**Command:**
```bash
tflint --init
tflint --chdir environments/nonprod/compute
```

**What it does:**
TFLint is a linter that understands Terraform AND the AWS provider. It goes beyond
`validate` to catch provider-specific issues.

**Example rules (aws plugin):**
- `aws_instance_invalid_type` — catches `t3.micr` (typo) before AWS rejects it
- `terraform_documented_variables` — every variable must have a description
- `terraform_required_version` — versions.tf must declare required_version
- `terraform_naming_convention` — resource names must follow the configured pattern

**Why it matters:**
Validate only knows Terraform syntax. TFLint knows that `t3.micr` is not a valid
EC2 instance type — it catches the error without spending money on a failed plan.

---

## 4. tfsec — static security scan

**Command:**
```bash
tfsec . --minimum-severity HIGH --format junit
```

**What it does:**
Scans all `.tf` files for known security misconfigurations. Maintained by Aqua Security.
Produces JUnit XML (shown in the pipeline test results tab) and SARIF (for Azure
DevOps Advanced Security).

**Example rules:**
| Rule ID | What it catches |
|---------|----------------|
| AVD-AWS-0028 | IMDSv2 not enforced on EC2 |
| AVD-AWS-0131 | EBS volume not encrypted |
| AVD-AWS-0094 | S3 bucket not blocking public access |
| AVD-AWS-0057 | S3 bucket not enforcing TLS |

**Severity threshold:**
HIGH and CRITICAL fail the pipeline. MEDIUM and LOW are reported but do not block.
This is a deliberate choice — MEDIUM findings should be reviewed and triaged, but
not every pipeline run should fail on a MEDIUM finding that is a known accepted risk.

---

## 5. checkov — static security scan

**Command:**
```bash
checkov --directory . --framework terraform --hard-fail-on HIGH,CRITICAL
```

**What it does:**
Similar to tfsec but maintained by Palo Alto (Bridgecrew). Different rule set.
Running both means a gap in one is caught by the other.

**Example rules tfsec misses that Checkov catches:**
| Check ID | What it catches |
|----------|----------------|
| CKV_AWS_119 | DynamoDB not encrypted with KMS |
| CKV_AWS_111 | IAM policy allows * actions |
| CKV2_AWS_6 | S3 bucket does not have public access block |

**Why run both:**
No single scanner has 100% rule coverage. The overlap is small — most rules are
unique to each tool. The cost (a few seconds of parallel CI time) is worth catching
the extra findings.

---

## 6. docs — terraform-docs README drift

**Command:**
```bash
terraform-docs markdown table --output-mode inject modules/aws/ec2
diff modules/aws/ec2/README.md <generated>
```

**What it does:**
Regenerates the module README from the variables and outputs in the `.tf` files,
then diffs it against the committed README. Fails if they differ.

**Why it matters:**
Module documentation rots. Developers add a variable, forget to update the README,
and the next person to use the module works from wrong docs.
This check makes stale docs a CI failure — documentation is treated like code.

**Fixing a failure:**
```bash
terraform-docs markdown table --output-mode inject modules/aws/ec2
terraform-docs markdown table --output-mode inject modules/aws/s3
git add modules/aws/ec2/README.md modules/aws/s3/README.md
git commit -m "docs: update terraform-docs"
```

---

## Gate summary

| Job | Cloud creds needed | Blocks on | Auto-fixable |
|-----|--------------------|-----------|--------------|
| fmt | No | Any formatting difference | Yes (`terraform fmt`) |
| validate | No | Syntax / type errors | No — fix the HCL |
| lint | No | Provider-specific issues, missing docs | Mostly yes |
| tfsec | No | HIGH/CRITICAL security findings | No — fix the resource config |
| checkov | No | HIGH/CRITICAL security findings | No — fix the resource config |
| docs | No | README out of date with .tf files | Yes (`terraform-docs`) |
