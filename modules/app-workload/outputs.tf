output "namespace" {
  value = kubernetes_namespace_v1.this.metadata[0].name
}

output "service_account" {
  value = kubernetes_service_account_v1.this.metadata[0].name
}

output "bucket_name" {
  value = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}

output "role_arn" {
  value = aws_iam_role.this.arn
}

output "policy_json" {
  description = "Rendered policy JSON."
  value       = data.aws_iam_policy_document.app.json
}
