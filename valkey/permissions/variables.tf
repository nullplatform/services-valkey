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
