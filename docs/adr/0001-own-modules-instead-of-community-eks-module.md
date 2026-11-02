# 0001: Own modules instead of terraform-aws-modules/eks

Status: accepted

## Context

The community EKS and VPC modules are good, but they have hundreds of inputs and
create the IAM roles internally. For an exercise about IAM, the interesting
decisions would be hidden in someone else's code.

## Decision

Three small modules (`network`, `eks-cluster`, `app-workload`) with plain
`aws_*` resources. Every IAM statement is in this repo.

## Consequences

- Easy to review and easy to change live.
- We maintain them. In a real team I'd probably move to the community modules
  later and keep `app-workload` as ours.
- The `node_groups` type is declared in both the root and the module. Terraform
  can't share types between modules.
