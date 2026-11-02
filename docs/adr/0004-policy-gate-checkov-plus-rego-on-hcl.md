# 0004: Policy gate with Checkov plus Rego on the HCL

Status: accepted

## Decision

`scripts/check-policies.sh`, Docker only:

1. Checkov, limited to IAM checks in `.checkov.yaml`.
2. conftest with `policy/opa/iam.rego` on the `.tf` files, with unit tests.
3. A canary with a typical bad policy. If either tool passes it, the script
   fails, so the gate can't silently stop working.

## Why both

On the canary, Checkov misses the `AmazonS3FullAccess` attachment and the open
trust policy. The Rego rules catch them but don't model escalation paths like
Checkov does. Checkov is the generic baseline; Rego has our conventions.

## Why HCL and not the plan

Bucket, key and cluster ARNs are unknown until apply, so the policy in the plan
is `(known after apply)`. The HCL always has the actions and resources. The
cost: statements must be written literally, not built from locals, and
`jsonencode()` policies are rejected. That's easier for human reviewers too.

## Not blocking on the full Checkov scan

It also flags flow logs, retention, replication... Worth doing, but failing an
IAM gate on them teaches people to ignore it. `--full` prints them as a report.

## On a real account

Add Access Analyzer `validate-policy` and `check-no-new-access` on the rendered
policies.
