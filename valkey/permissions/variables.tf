variable "link_id" {
  type        = string
  description = "Nullplatform link ID"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "user_group_id" {
  type        = string
  description = "User group of the target cache, derived from the service by build_permissions_context"
}

variable "user_name" {
  type        = string
  description = "Valkey user created for this link, derived from the link slug and ID"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,39}$", var.user_name)) && !can(regex("--", var.user_name)) && !endswith(var.user_name, "-") && var.user_name != "default"
    error_message = "user_name must be 1-40 lowercase alphanumeric characters or hyphens, start with a letter, not end with a hyphen, not contain consecutive hyphens and not be the reserved name default"
  }
}

variable "auth_mode" {
  type        = string
  default     = "password"
  description = "password for a VPC cache; iam for a public cache, which only accepts IAM-authenticated users"

  validation {
    condition     = contains(["password", "iam"], var.auth_mode)
    error_message = "auth_mode must be \"password\" or \"iam\""
  }
}

variable "cache_arn" {
  type        = string
  default     = ""
  description = "ARN of the cache the link's IAM user may connect to. Required when auth_mode is iam"

  validation {
    condition     = var.auth_mode != "iam" || can(regex("^arn:aws[a-z-]*:elasticache:", var.cache_arn))
    error_message = "cache_arn must be the cache's ARN when auth_mode is iam"
  }
}
