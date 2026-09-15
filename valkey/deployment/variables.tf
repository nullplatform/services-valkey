variable "service_id" {
  type        = string
  description = "Nullplatform service ID"
}

variable "cache_name" {
  type        = string
  description = "Serverless cache name. Derived from the service slug and ID by build_context"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,39}$", var.cache_name)) && !can(regex("--", var.cache_name)) && !endswith(var.cache_name, "-")
    error_message = "cache_name must be 1-40 lowercase alphanumeric characters or hyphens, start with a letter, not end with a hyphen and not contain consecutive hyphens"
  }
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "vpc_id" {
  type        = string
  description = "VPC the cache and its security group are placed in"
}

variable "subnet_ids" {
  type        = string
  description = "Comma-separated subnet IDs the cache is placed in"

  validation {
    condition     = length(compact([for s in split(",", var.subnet_ids) : trimspace(s)])) > 0
    error_message = "subnet_ids must contain at least one subnet ID"
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags applied to every resource"
}
