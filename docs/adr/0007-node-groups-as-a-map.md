# 0007: Node groups as a map, autoscaler owns desired_size

Status: accepted

## Decision

`node_groups` is a `map(object)` with optional labels, taints and capacity type,
one `aws_eks_node_group` per entry with `for_each`. `desired_size` is in
`ignore_changes`.

## Why

- A new group is a tfvars entry. The map key is in the resource address, so
  adding one doesn't touch the others (a list with `count` would).
- After creation the autoscaler sets the size; otherwise every apply would
  reset it.
- Taints use the EKS spelling (`NO_SCHEDULE`). Validation rejects `NoSchedule`
  at plan time.

## Consequences

- Changing `desired_size` later does nothing. Use min/max.
- Renaming a key replaces the group: add the new one, move pods, remove the old.
