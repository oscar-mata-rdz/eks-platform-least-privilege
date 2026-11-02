data "aws_iam_policy_document" "assume" {
  statement {
    sid     = "PodIdentityForThisServiceAccountOnly"
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks-cluster-arn"
      values   = [var.cluster_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-namespace"
      values   = [local.namespace]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes-service-account"
      values   = [local.service_account]
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = "${var.name_prefix}-${var.app_name}-${local.region}"
  description          = "Pod Identity role for ${local.namespace}/${local.service_account}"
  assume_role_policy   = data.aws_iam_policy_document.assume.json
  max_session_duration = 3600
  permissions_boundary = var.permissions_boundary_arn
  tags                 = var.tags
}

data "aws_iam_policy_document" "app" {
  statement {
    sid       = "ListOwnBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.this.arn]
  }

  statement {
    sid       = "ReadOwnObjects"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }

  dynamic "statement" {
    for_each = local.can_write ? [1] : []
    content {
      sid       = "WriteOwnObjects"
      actions   = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.this.arn}/*"]
    }
  }

  dynamic "statement" {
    for_each = local.can_write && var.allow_delete ? [1] : []
    content {
      sid       = "DeleteOwnObjects"
      actions   = ["s3:DeleteObject"]
      resources = ["${aws_s3_bucket.this.arn}/*"]
    }
  }

  statement {
    sid       = "DecryptViaS3"
    actions   = ["kms:Decrypt"]
    resources = [aws_kms_key.bucket.arn]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${local.region}.amazonaws.com"]
    }
  }

  dynamic "statement" {
    for_each = local.can_write ? [1] : []
    content {
      sid       = "EncryptViaS3"
      actions   = ["kms:GenerateDataKey"]
      resources = [aws_kms_key.bucket.arn]

      condition {
        test     = "StringEquals"
        variable = "kms:ViaService"
        values   = ["s3.${local.region}.amazonaws.com"]
      }
    }
  }
}

resource "aws_iam_policy" "app" {
  name        = "${var.name_prefix}-${var.app_name}-${local.region}"
  description = "Least-privilege access for ${var.app_name} to its own bucket"
  policy      = data.aws_iam_policy_document.app.json
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.app.arn
}

resource "aws_eks_pod_identity_association" "this" {
  cluster_name    = var.cluster_name
  namespace       = kubernetes_namespace_v1.this.metadata[0].name
  service_account = kubernetes_service_account_v1.this.metadata[0].name
  role_arn        = aws_iam_role.this.arn
  tags            = var.tags
}
