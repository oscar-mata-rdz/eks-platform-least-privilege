# 0003: One root module, one state per region

Status: accepted for the exercise

## Decision

- One root (`platform/`) and one tfvars per region.
- One workspace per region, named after it. A precondition fails the plan if
  the workspace doesn't match `var.region`.
- Everything regional comes from variables; ARNs use `aws_partition` and
  `aws_region`.
- IAM names include the region, since IAM is global.

## Why

A region should deploy and break on its own. The guard is there for the one
classic workspace mistake: right tfvars, wrong workspace, and a plan that
destroys one region to build the other.

## What I'd change in production

- S3 backend with a key per team and region instead of local state.
- Split into `platform/` (network, cluster) and `workloads/` (namespaces, app
  roles). Configuring the Kubernetes provider from a cluster created in the same
  root works, but breaks when the cluster is replaced. I kept one root so a
  single plan shows everything.
