variable "cluster_name" {
  description = "Cluster name."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{0,99}$", var.cluster_name))
    error_message = "Invalid cluster_name."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets, 2+ AZs."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Needs at least 2 subnets."
  }
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
    condition     = !contains(var.public_access_cidrs, "0.0.0.0/0")
    error_message = "0.0.0.0/0 not allowed."
  }
}

variable "cluster_log_types" {
  description = "Control plane log types."
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "log_retention_days" {
  description = "Log retention in days."
  type        = number
  default     = 90
}

variable "kms_deletion_window_in_days" {
  description = "KMS key deletion window."
  type        = number
  default     = 30
}

variable "node_groups" {
  description = "Managed node groups, keyed by name."
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

  validation {
    condition     = length(var.node_groups) > 0
    error_message = "Define at least one node group."
  }

  validation {
    condition = alltrue([
      for ng in values(var.node_groups) : ng.min_size <= ng.desired_size && ng.desired_size <= ng.max_size
    ])
    error_message = "Needs min_size <= desired_size <= max_size."
  }

  validation {
    condition = alltrue(flatten([
      for ng in values(var.node_groups) : [
        for t in ng.taints : contains(["NO_SCHEDULE", "NO_EXECUTE", "PREFER_NO_SCHEDULE"], t.effect)
      ]
    ]))
    error_message = "Taint effect must be NO_SCHEDULE, NO_EXECUTE or PREFER_NO_SCHEDULE."
  }

  validation {
    condition     = alltrue([for ng in values(var.node_groups) : contains(["ON_DEMAND", "SPOT"], ng.capacity_type)])
    error_message = "capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}
