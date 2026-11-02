variable "region" {
  description = "AWS region (same as workspace)."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-\\d$", var.region))
    error_message = "Invalid region."
  }
}

variable "allowed_account_ids" {
  description = "Allowed AWS account IDs."
  type        = list(string)
}

variable "team" {
  description = "Team name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,15}$", var.team))
    error_message = "Lowercase, 2-16 chars."
  }
}

variable "environment" {
  description = "Environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging or prod."
  }
}

variable "tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string
}

variable "az_count" {
  description = "Number of AZs (2-3)."
  type        = number
  default     = 3
}

variable "single_nat_gateway" {
  description = "One NAT for all AZs."
  type        = bool
  default     = false
}

variable "kubernetes_version" {
  description = "Kubernetes version."
  type        = string
}

variable "endpoint_public_access" {
  description = "Public API endpoint on or off."
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "CIDRs allowed on the public endpoint."
  type        = list(string)
  default     = []

  validation {
    condition     = !var.endpoint_public_access || length(var.public_access_cidrs) > 0
    error_message = "Public endpoint needs CIDRs."
  }
}

variable "node_groups" {
  description = "Managed node groups."
  type = map(object({
    instance_types             = list(string)
    min_size                   = number
    max_size                   = number
    desired_size               = number
    capacity_type              = optional(string, "ON_DEMAND")
    ami_type                   = optional(string, "AL2023_x86_64_STANDARD")
    disk_size                  = optional(number, 50)
    max_unavailable_percentage = optional(number, 33)
    labels                     = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
  }))
}

variable "apps" {
  description = "Apps on this cluster, keyed by name."
  type = map(object({
    namespace       = optional(string)
    service_account = optional(string)
    bucket_access   = optional(string, "read-write")
    allow_delete    = optional(bool, false)
  }))
  default = {}
}
