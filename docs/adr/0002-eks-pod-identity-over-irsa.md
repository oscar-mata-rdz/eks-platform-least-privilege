# 0002: EKS Pod Identity instead of IRSA

Status: accepted

## Context

Pods need AWS credentials. IRSA needs an OIDC provider per cluster and a trust
policy tied to it. Pod Identity uses an add-on and one association per service
account, and trusts `pods.eks.amazonaws.com`.

## Decision

Pod Identity. The trust policy still pins:

- `aws:RequestTag/eks-cluster-arn`: this cluster
- `aws:RequestTag/kubernetes-namespace` and `kubernetes-service-account`: this
  service account

These are session tags Pod Identity sends on every AssumeRole, and the EKS docs
use them in trust policies. I first used `aws:SourceArn`/`aws:SourceAccount`,
but EKS documents those for the cluster role, not for pods. A key that isn't
sent would lock every pod out, and LocalStack wouldn't show it.

## Why

- No OIDC provider per cluster, and nothing to change when a cluster is rebuilt.
- One role can serve several clusters by listing their ARNs.
- It's what AWS recommends for new clusters.

The usual objection is that the binding lives in the association, not the
trust policy. The conditions fix that: an association to the wrong service
account gets AccessDenied.

## Consequences

- Needs the `eks-pod-identity-agent` add-on (the module installs it).
- `disable_session_tags` has to stay `false`.
- IRSA is the fallback for clusters without the add-on; only the trust policy
  changes.
