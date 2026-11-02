variable "name" {
  description = "Name prefix."
  type        = string
}

variable "cluster_name" {
  description = "Cluster name, for subnet tags."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) <= 16
    error_message = "vpc_cidr must be /16 or larger."
  }
}

variable "az_count" {
  description = "Number of AZs."
  type        = number
  default     = 3

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3."
  }
}

variable "single_nat_gateway" {
  description = "One NAT for all AZs."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}
