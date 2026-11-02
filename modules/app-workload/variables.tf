variable "app_name" {
  description = "App name, e.g. payments-service."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,40}$", var.app_name))
    error_message = "app_name: lowercase, numbers and hyphens, 2-41 chars."
  }
}

variable "name_prefix" {
  description = "Name prefix, usually <team>-<env>."
  type        = string
}

variable "cluster_name" {
  description = "Cluster name."
  type        = string
}

variable "cluster_arn" {
  description = "Cluster ARN, used in the trust policy."
  type        = string
}

variable "namespace" {
  description = "Namespace. Defaults to app_name."
  type        = string
  default     = null
}

variable "service_account_name" {
  description = "Service account. Defaults to app_name."
  type        = string
  default     = null
}

variable "bucket_name" {
  description = "Bucket name override."
  type        = string
  default     = null
}

variable "bucket_access" {
  description = "read-only or read-write."
  type        = string
  default     = "read-write"

  validation {
    condition     = contains(["read-only", "read-write"], var.bucket_access)
    error_message = "Must be read-only or read-write."
  }
}

variable "allow_delete" {
  description = "Allow s3:DeleteObject (read-write only)."
  type        = bool
  default     = false
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary."
  type        = string
  default     = null
}

variable "kms_deletion_window_in_days" {
  description = "KMS key deletion window."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}
