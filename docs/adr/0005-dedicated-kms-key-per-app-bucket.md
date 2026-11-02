# 0005: A dedicated KMS key per app bucket

Status: accepted

SSE-S3 or the `aws/s3` key would need no IAM at all. I went with one customer
managed key per app bucket (rotation on, bucket key enabled), and the role can
only use it through S3 in its region (`kms:ViaService`).

Why:

- The policy names one key. With `aws/s3`, anyone who can read any bucket in
  the account can decrypt.
- Revoking access to the data is one key policy change.
- `ViaService` means the role can't call KMS directly.

The rest of the bucket setup supports the IAM policy: versioning is what makes
leaving out `DeleteObject` mean something, and with ACLs off (`BucketOwnerEnforced`)
the role never needs `s3:*Acl`. Public access is blocked and non-TLS requests
are denied.

Cost is two extra KMS actions and some KMS requests, mostly absorbed by the
bucket key. A deleted key means lost data, so the deletion window is a variable.
