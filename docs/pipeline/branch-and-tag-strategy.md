# Branch and Tag Strategy

---

## Branch model

```
main  ←  the single source of truth
  │
  ├── feature/add-sg-rule        daily dev work
  ├── fix/ebs-encryption-flag    bug fixes
  └── release-1.0.0              Git tag (not a branch)
```

There is no long-lived `develop` or `staging` branch.
The environment separation happens through **pipeline stages and tags**, not branches.

---

## What triggers what

```
Push / merge to main
  → CI quality gates
  → Plan + Apply nonprod  (automatic, subject to approval)
  → Prod stages SKIPPED

Push a release-* tag
  → CI quality gates
  → Plan + Apply nonprod
  → Plan + Apply prod  (subject to approval + branch control)

Open a PR to main
  → CI quality gates only
  → No deployment
```

---

## Branch protection on main

Configure this in Azure DevOps under Repos → Branches → main → Branch policies:

```
☑ Require a minimum number of reviewers: 1 (2 for security changes)
☑ Check for linked work items
☑ Check for comment resolution
☑ Limit merge types: Squash merge only  (clean history)
☑ Build validation: iac-platform-compute-cd  (CI must pass)
```

This means:
- No direct push to main — all changes via PR
- CI must pass on the PR before merge is allowed
- At least one reviewer must approve

---

## Tag convention

Tags are the release mechanism. They are **annotated** (not lightweight)
so they carry a message and are signed with the tagger's identity.

```
Format:   release-<major>.<minor>.<patch>
Examples: release-1.0.0
          release-1.1.0
          release-2.0.0
```

Semver rules for IaC changes:

| Change type | Version bump | Example |
|-------------|-------------|---------|
| New resource or feature | minor | 1.0.0 → 1.1.0 |
| Bug fix, config change, no new resources | patch | 1.0.0 → 1.0.1 |
| Destructive change (resource replacement, rename) | major | 1.0.0 → 2.0.0 |

**Creating a release tag:**
```bash
git checkout main
git pull

# Check what changed since the last tag
git log release-1.0.0..HEAD --oneline

# Tag it
git tag -a release-1.1.0 -m "Release 1.1.0 — add lifecycle rules to S3 bucket"
git push origin release-1.1.0
```

---

## Why tags trigger prod (not branches)

Branches are mutable. `main` can be force-pushed (even with protections, a repo admin
can override). A branch name gives you no guarantee about what commit is behind it.

A Git tag is:
- Immutable once pushed (you cannot move it without deleting and recreating it)
- Explicitly named (the name is a human decision, not an automatic label)
- An audit point — `release-1.1.0` always refers to exactly one commit, forever

The prod pipeline condition and the ADO Environment branch control both check for
`refs/tags/release-*` — meaning: *"only deploy to prod from a deliberately, explicitly
named release point."*

---

## Hotfix flow (urgent prod fix)

If prod needs an urgent fix outside the normal release cycle:

```bash
# 1. Fix directly on main (via PR — no shortcuts)
git checkout -b fix/urgent-sg-rule
# make the fix
git push origin fix/urgent-sg-rule
# raise PR, get it reviewed and merged to main fast-track

# 2. Tag immediately after merge
git checkout main && git pull
git tag -a release-1.0.1 -m "Hotfix 1.0.1 — restrict SG rule to VPC CIDR"
git push origin release-1.0.1
```

Nonprod deploys first (from the tag, as normal).
After nonprod succeeds and CAB approves, prod deploys.
Even a hotfix goes through nonprod — there are no "skip nonprod" shortcuts.
