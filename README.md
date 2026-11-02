# EKS platform foundation with least-privilege access

A VPC, an EKS cluster with managed node groups, and one app (`payments-service`)
with its own namespace, its own S3 bucket and an IAM role that can touch that
bucket and nothing else. The same code plans `us-east-1` and `us-west-2` from
two tfvars files.

It all runs against LocalStack. You don't need an AWS account, and the code
refuses to run against a real one (see [Safety](#safety)).

Design decisions are in [`docs/adr/`](docs/adr):

1. [Own modules instead of terraform-aws-modules/eks](docs/adr/0001-own-modules-instead-of-community-eks-module.md)
2. [EKS Pod Identity instead of IRSA](docs/adr/0002-eks-pod-identity-over-irsa.md)
3. [One root module, one state per region](docs/adr/0003-one-root-one-workspace-per-region.md)
4. [Policy gate: Checkov plus Rego on the HCL](docs/adr/0004-policy-gate-checkov-plus-rego-on-hcl.md)
5. [A dedicated KMS key per app bucket](docs/adr/0005-dedicated-kms-key-per-app-bucket.md)
6. [AWS managed policies for the cluster and node roles](docs/adr/0006-aws-managed-policies-for-cluster-and-nodes.md)
7. [Node groups as a map, autoscaler owns desired_size](docs/adr/0007-node-groups-as-a-map.md)
8. [Ordering through outputs, not module-level depends_on](docs/adr/0008-ordering-through-outputs-not-module-depends-on.md)
9. [Network layout](docs/adr/0009-network-layout.md)

## Running it

You need Docker and Terraform. I used Terraform 1.16.6 (anything `>= 1.9, < 2.0`
should work), AWS provider 6.70.0 and Kubernetes provider 3.4.0, both pinned
with the lock file committed, and Docker 28. LocalStack is pinned to 4.14.0 in
`docker-compose.yml`.

Why 4.14.0: newer LocalStack images won't start without an auth token, and this
is the last community one that does. Community doesn't include EKS, but `init`,
`validate` and `plan` never call the EKS API, so that's enough here. An `apply`
can't finish without EKS, so I stopped at `plan`.

```bash
docker compose up -d --wait        # start LocalStack
source localstack.env              # endpoint + dummy test/test credentials

cd platform
terraform init

terraform workspace select -or-create us-east-1
terraform plan -var-file=envs/us-east-1.tfvars

terraform workspace select -or-create us-west-2
terraform plan -var-file=envs/us-west-2.tfvars

cd ..
scripts/check-policies.sh          # IAM policy gate, only needs Docker
```

Or `make up`, `make plan` (both regions) and `make check`.

Don't skip the workspace step. Each region has its own state, and running a
region's tfvars in the wrong workspace stops with an error telling you which
one to select.

### Safety

- No credentials, real account IDs or state files in the repo. The only
  account ID is `000000000000`, LocalStack's.
- The provider has `allowed_account_ids = ["000000000000"]`. If you forget to
  source `localstack.env` and have real credentials in your shell, Terraform
  refuses to run.
- `localstack.env` also unsets `AWS_PROFILE` and `AWS_SESSION_TOKEN`. Nothing
  in the `.tf` files is LocalStack-specific; it's all `AWS_ENDPOINT_URL`.

## Layout

```
modules/
  network/        VPC, subnets in 2-3 AZs, NAT, routing
  eks-cluster/    cluster, its IAM roles, KMS for secrets, logs, node groups, pod identity agent
  app-workload/   one app: namespace, service account, bucket + KMS key, IAM role, pod identity association
platform/         root module, wires the three together
  envs/           one tfvars per region
policy/           conftest rules, tests, and a bad policy the gate must reject
scripts/          check-policies.sh
docs/             ADRs and evidence
```

`network` and `eks-cluster` are what a platform team owns. `app-workload` is
what an app team asks for. None of the modules know about payments, regions or
LocalStack; that all comes from the tfvars.

## Part 1: cluster and node groups

The cluster runs in private subnets. The private endpoint is always on, the
public one is optional and limited to listed CIDRs (`0.0.0.0/0` is rejected by
validation). Auth is access entries only (`authentication_mode = "API"`),
secrets are encrypted with a KMS key, and control plane logs go to a log group
Terraform owns so retention is ours to set.

Node groups are a map, so a new one is a tfvars change. For example, a spot
group for batch jobs that only pods with the toleration land on:

```hcl
batch = {
  instance_types = ["c6i.xlarge"]
  capacity_type  = "SPOT"
  min_size       = 0
  max_size       = 10
  desired_size   = 0
  labels         = { workload = "batch" }
  taints         = [{ key = "workload", value = "batch", effect = "NO_SCHEDULE" }]
}
```

The effect is `NO_SCHEDULE` (EKS API), not `NoSchedule` (kubectl). Validation
catches that one.

The `payments` namespace comes from `app-workload`, with Pod Security Admission
on `restricted` and a service account that doesn't mount an API token. A second
team is just another tfvars:

```hcl
team = "lending"
apps = {
  loan-engine = { bucket_access = "read-only" }
}
```

## Part 2: the IAM policy

Everything is in [`modules/app-workload/iam.tf`](modules/app-workload/iam.tf).
For a read-write app the role gets five statements:

| Sid | Action | Resource |
|---|---|---|
| ListOwnBucket | `s3:ListBucket` | the bucket |
| ReadOwnObjects | `s3:GetObject` | `bucket/*` |
| WriteOwnObjects | `s3:PutObject` | `bucket/*` |
| DecryptViaS3 | `kms:Decrypt` | the bucket's key, only via S3 in this region |
| EncryptViaS3 | `kms:GenerateDataKey` | same |

A read-only app gets the first, second and fourth only.

### What's in, and why

- Get and Put on `bucket/*` are what "read and write objects" means. Object
  actions go on the object ARN, bucket actions on the bucket ARN; mixing them
  up is usually how people end up writing `s3:*`.
- `ListBucket` so a missing key returns 404 instead of 403. Otherwise the app
  can't tell "not there yet" from "not allowed".
- The two KMS actions because the bucket uses SSE-KMS with its own key.
  `kms:ViaService` means the role can only use the key through S3, not call
  KMS directly.

The trust policy matters as much. Only `pods.eks.amazonaws.com` can assume the
role, and only when the session tags match this cluster ARN, the `payments`
namespace and the `payments-service` service account. The association already
binds the role to that service account, but anyone with
`eks:CreatePodIdentityAssociation` could point it somewhere else; with these
conditions the role refuses.

I didn't use `aws:SourceArn`/`aws:SourceAccount`. EKS documents them for the
cluster role, not for `pods.eks.amazonaws.com`, while the session tags are
documented for exactly this
([EKS docs](https://docs.aws.amazon.com/eks/latest/userguide/pod-id-role.html)).
A condition on a key that isn't sent locks every pod out, and LocalStack would
never show it.

### What I left out

| Left out | Why |
|---|---|
| `s3:*`, `s3:Get*`, `s3:Put*` | Also grant `PutBucketPolicy`, `PutObjectAcl`, `GetBucketPolicy`... The app needs two object actions. |
| `s3:DeleteObject` | Most services never delete. Behind `allow_delete = false`, and versioning keeps old versions anyway. |
| `s3:ListAllMyBuckets` | The app gets its bucket name from config. |
| ACL, tagging, version actions | Not used. ACLs are off (`BucketOwnerEnforced`). |
| Bucket config actions | Encryption, versioning and the bucket policy belong to Terraform, not the app. |
| `kms:Encrypt`, `ReEncrypt*`, `CreateGrant`, `DescribeKey` | SSE-KMS only needs `GenerateDataKey` and `Decrypt`. |

The bucket itself blocks public access, has ACLs off, denies non-TLS requests
and encrypts by default with its key.

### How I'd review it

If a teammate sent me this policy, I'd go through it in this order:

1. Who can assume it? A perfect policy on a role anyone can assume is
   worthless. Is the principal specific, is it pinned, and are the condition
   keys ones that principal actually sends?
2. Any `*` in Action or Resource? Each one needs a reason, usually "this action
   has no resource-level permissions", which you can check in the
   [Service Authorization Reference](https://docs.aws.amazon.com/service-authorization/latest/reference/reference_policies_actions-resources-contextkeys.html).
3. Which SDK call needs each action? If nobody can point to one, it goes.
4. Right resource type for each action? Object actions on a bucket ARN grant
   nothing, and the next "fix" is usually a wildcard.
5. Anything that hands out more access (`iam:PassRole`, `iam:*Policy*`,
   `sts:AssumeRole`, `kms:CreateGrant`)? Second reviewer, even when scoped.
6. Can data leave the account (`PutBucketPolicy`, `PutObjectAcl`, write to an
   outside bucket)?

After it ships: Access Analyzer unused-access findings and CloudTrail to see
what the role really calls, and trim. The module also takes a
`permissions_boundary_arn` for accounts where app teams create their own roles.

## Part 3: multiple regions

One root module, one tfvars per region. Region, CIDR, AZ count, NAT layout,
node sizes and endpoint exposure all come from the tfvars; ARNs are built with
`aws_partition` and `aws_region`.

| | `us-east-1` | `us-west-2` |
|---|---|---|
| Role | primary | standby |
| VPC CIDR | `10.10.0.0/16` | `10.20.0.0/16` |
| AZs / NAT | 3, one NAT per AZ | 2, one shared NAT |
| Nodes | 2-6, 3 desired | 1-4, 2 desired |
| Public API endpoint | on, one CIDR | off |
| Resources in plan | 52 | 43 |

Each region has its own workspace and state, so one region can break without
touching the other. A precondition stops the plan if the workspace doesn't
match `var.region`; without it, planning `us-west-2.tfvars` on the `us-east-1`
state would destroy one region to build the other.

IAM names include the region. IAM is global, so without it the second region
would collide with the first in the same account, and since each plan has its
own state, LocalStack would never show that. More in ADR 0003.

## Bonus: IAM policy gate

`scripts/check-policies.sh` runs:

1. Checkov, only its IAM checks (`.checkov.yaml`).
2. conftest with [`policy/opa/iam.rego`](policy/opa/iam.rego): no wildcard
   actions (including `s3:Get*`), no `*` resources outside a short allowlist,
   no `NotAction`/`NotResource`, no `Principal: "*"`, Pod Identity trust must
   pin cluster, namespace and service account, policies only through
   `aws_iam_policy_document`, no `*FullAccess`/admin attachments, and a
   warning on `iam:PassRole` and friends. The rules have unit tests.
3. A canary: `policy/testdata/overly-permissive/` is the PR you get after an
   hour of AccessDenied (`s3:*` on `*`, `AmazonS3FullAccess`, open trust). The
   script fails if either tool lets it through.

I use both because they catch different things. On the canary, Checkov flags
the wildcards but misses the FullAccess attachment and the open trust policy;
the Rego rules catch those. The rules read the HCL instead of the plan because
the ARNs are "known after apply" in a plan (ADR 0004).

CI (`.github/workflows/ci.yml`) runs fmt, validate, the gate and a plan per
region against LocalStack.

## Evidence

- [`plan-us-east-1.txt`](docs/evidence/plan-us-east-1.txt): 52 to add
- [`plan-us-west-2.txt`](docs/evidence/plan-us-west-2.txt): 43 to add
- [`policy-checks.txt`](docs/evidence/policy-checks.txt): gate passing
- [`policy-canary.txt`](docs/evidence/policy-canary.txt): gate rejecting the bad fixture

`make evidence` regenerates the plans and `policy-checks.txt`.

## On a real account, and with more time

- S3 backend with native locking, one key per team and region.
- CI assumes a role through GitHub OIDC; the apply role only works from `main`.
- Split cluster and workloads into separate states. Using the Kubernetes
  provider against a cluster created in the same apply works, but it's fragile.
- Turn off `bootstrap_cluster_creator_admin_permissions`, give admin to a
  platform role, and namespace-scoped access entries to each team.
- Access Analyzer `validate-policy` and `check-no-new-access` in CI.
- Move the CNI policy off the node role onto `aws-node` with Pod Identity.
- VPC endpoints for S3/ECR/STS, flow logs, an explicit KMS key policy.
- Karpenter instead of fixed node groups, and `terraform test` for the modules.
