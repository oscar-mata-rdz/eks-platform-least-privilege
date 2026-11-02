data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  region     = data.aws_region.current.region

  namespace       = coalesce(var.namespace, var.app_name)
  service_account = coalesce(var.service_account_name, var.app_name)

  bucket_name = coalesce(var.bucket_name, "${var.name_prefix}-${var.app_name}-${local.account_id}-${local.region}")

  can_write = var.bucket_access == "read-write"

  labels = {
    "app.kubernetes.io/name"       = var.app_name
    "app.kubernetes.io/managed-by" = "terraform"
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = local.namespace
    labels = merge(local.labels, {
      "pod-security.kubernetes.io/enforce" = "restricted"
    })
  }
}

resource "kubernetes_service_account_v1" "this" {
  metadata {
    name      = local.service_account
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = local.labels
  }

  automount_service_account_token = false
}
