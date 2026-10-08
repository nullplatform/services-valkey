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
  default     = ""
  description = "VPC the cache and its security group are placed in. Unused by a public cache"

  validation {
    condition     = var.connection_type == "public" || var.vpc_id != ""
    error_message = "vpc_id is required for a VPC cache"
  }
}

variable "subnet_ids" {
  type        = list(string)
  default     = []
  description = "Subnets the cache is placed in, from vpc.subnets of the vpc provider or the developer's override. Unused by a public cache"

  validation {
    condition     = var.connection_type == "public" || length(var.subnet_ids) > 0
    error_message = "subnet_ids must contain at least one subnet ID for a VPC cache"
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags applied to every resource"
}

variable "kms_key_arn" {
  type        = string
  default     = null
  description = "ARN of an existing KMS key for the cache's at-rest encryption. When null, the module creates a dedicated key for this cache."
}

variable "engine_version" {
  type        = string
  default     = "9"
  description = "Valkey major engine version for the serverless cache. It can be upgraded, never downgraded"

  validation {
    condition     = contains(["7", "8", "9"], var.engine_version)
    error_message = "engine_version must be \"7\", \"8\" or \"9\" — the major versions ElastiCache Serverless supports for Valkey"
  }
}

variable "connection_type" {
  type        = string
  default     = "vpc"
  description = "vpc reaches the cache through a VPC endpoint; public over the internet with IAM authentication. Fixed after creation"

  validation {
    condition     = contains(["vpc", "public"], var.connection_type)
    error_message = "connection_type must be \"vpc\" or \"public\""
  }

  validation {
    condition     = var.connection_type == "vpc" || var.engine_version == "9"
    error_message = "the public connection type requires Valkey 9"
  }
}

variable "network_type" {
  type        = string
  default     = "ipv4"
  description = "IP version(s) the cache supports. ipv6 needs IPv6-only subnets, dual_stack subnets with an IPv6 range. Fixed after creation"

  validation {
    condition     = contains(["ipv4", "ipv6", "dual_stack"], var.network_type)
    error_message = "network_type must be \"ipv4\", \"ipv6\" or \"dual_stack\""
  }
}

variable "security_group_ids" {
  type        = list(string)
  default     = []
  description = "Security groups that replace the default one the module creates. Empty keeps the default. Ignored by a public cache"
}

variable "snapshot_retention_limit" {
  type        = number
  default     = 0
  description = "Days automatic backups are kept. 0 turns automatic backups off"

  validation {
    condition     = var.snapshot_retention_limit >= 0 && var.snapshot_retention_limit <= 35 && floor(var.snapshot_retention_limit) == var.snapshot_retention_limit
    error_message = "snapshot_retention_limit must be a whole number of days between 0 and 35"
  }
}

variable "daily_snapshot_time" {
  type        = string
  default     = ""
  description = "UTC time (HH:MM) the daily backup starts. Empty lets AWS choose"

  validation {
    condition     = var.daily_snapshot_time == "" || can(regex("^([01][0-9]|2[0-3]):[0-5][0-9]$", var.daily_snapshot_time))
    error_message = "daily_snapshot_time must be empty or a UTC time as HH:MM"
  }
}

variable "data_storage_minimum_gb" {
  type        = number
  default     = null
  description = "Minimum data storage in GB. Null for no minimum"

  validation {
    condition     = var.data_storage_minimum_gb == null || (var.data_storage_minimum_gb >= 1 && var.data_storage_minimum_gb <= 5000)
    error_message = "data_storage_minimum_gb must be between 1 and 5000"
  }
}

variable "data_storage_maximum_gb" {
  type        = number
  default     = null
  description = "Maximum data storage in GB. Null for no maximum"

  validation {
    condition     = var.data_storage_maximum_gb == null || (var.data_storage_maximum_gb >= 1 && var.data_storage_maximum_gb <= 5000)
    error_message = "data_storage_maximum_gb must be between 1 and 5000"
  }
}

variable "ecpu_minimum" {
  type        = number
  default     = null
  description = "Minimum ECPUs per second. Null for no minimum"

  validation {
    condition     = var.ecpu_minimum == null || (var.ecpu_minimum >= 1000 && var.ecpu_minimum <= 15000000)
    error_message = "ecpu_minimum must be between 1000 and 15000000"
  }
}

variable "ecpu_maximum" {
  type        = number
  default     = null
  description = "Maximum ECPUs per second. Null for no maximum"

  validation {
    condition     = var.ecpu_maximum == null || (var.ecpu_maximum >= 1000 && var.ecpu_maximum <= 15000000)
    error_message = "ecpu_maximum must be between 1000 and 15000000"
  }
}
