locals {
  common_tags = merge(var.tags, {
    "managed-by" = "nullplatform"
    "service-id" = var.service_id
  })

  # The aws provider has no connection type yet: a public cache is created through Cloud Control
  # (awscc). A VPC cache keeps the aws resource, so caches created before stay where they are.
  public = var.connection_type == "public"

  # The default security group allows Valkey from inside the VPC. Selected security groups
  # replace it, like in the console; a public cache has none.
  default_security_group = !local.public && length(var.security_group_ids) == 0

  # A dual stack or IPv6 cache is reached over the VPC's IPv6 ranges too.
  vpc_ipv6_cidr_blocks = local.default_security_group ? sort(compact([
    for association in data.aws_vpc.cache[0].ipv6_cidr_block_associations : association.ipv6_cidr_block
  ])) : []

  kms_key_arn         = var.kms_key_arn != null ? var.kms_key_arn : aws_kms_key.cache[0].arn
  daily_snapshot_time = var.daily_snapshot_time == "" ? null : var.daily_snapshot_time

  data_storage_limited = var.data_storage_minimum_gb != null || var.data_storage_maximum_gb != null
  ecpu_limited         = var.ecpu_minimum != null || var.ecpu_maximum != null
}

moved {
  from = data.aws_vpc.cache
  to   = data.aws_vpc.cache[0]
}

moved {
  from = aws_security_group.cache
  to   = aws_security_group.cache[0]
}

moved {
  from = aws_elasticache_serverless_cache.cache
  to   = aws_elasticache_serverless_cache.cache[0]
}

data "aws_vpc" "cache" {
  count = local.default_security_group ? 1 : 0

  id = var.vpc_id
}

resource "aws_security_group" "cache" {
  count = local.default_security_group ? 1 : 0

  name        = "${var.cache_name}-security-group"
  description = "Valkey access for ${var.cache_name} from inside the VPC"
  vpc_id      = var.vpc_id

  ingress {
    description      = "Valkey from the VPC"
    from_port        = 6379
    to_port          = 6379
    protocol         = "tcp"
    cidr_blocks      = [data.aws_vpc.cache[0].cidr_block]
    ipv6_cidr_blocks = local.vpc_ipv6_cidr_blocks
  }

  egress {
    description      = "All outbound inside the VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = [data.aws_vpc.cache[0].cidr_block]
    ipv6_cidr_blocks = local.vpc_ipv6_cidr_blocks
  }

  tags = local.common_tags
}

resource "aws_kms_key" "cache" {
  count = var.kms_key_arn == null ? 1 : 0

  description         = "Customer managed key for the ${var.cache_name} Valkey serverless cache"
  enable_key_rotation = true

  tags = local.common_tags
}

resource "aws_kms_alias" "cache" {
  count = var.kms_key_arn == null ? 1 : 0

  name          = "alias/nullplatform-valkey-${var.cache_name}"
  target_key_id = aws_kms_key.cache[0].key_id
}

resource "aws_elasticache_user_group" "cache" {
  engine        = "valkey"
  user_group_id = "${var.cache_name}-ug"

  tags = local.common_tags

  lifecycle {
    ignore_changes = [user_ids]
  }
}

resource "aws_elasticache_serverless_cache" "cache" {
  count = local.public ? 0 : 1

  engine               = "valkey"
  name                 = var.cache_name
  description          = "${var.cache_name} Valkey serverless cache"
  major_engine_version = var.engine_version
  user_group_id        = aws_elasticache_user_group.cache.user_group_id
  kms_key_id           = local.kms_key_arn
  security_group_ids   = local.default_security_group ? [aws_security_group.cache[0].id] : var.security_group_ids
  subnet_ids           = var.subnet_ids
  network_type         = var.network_type

  snapshot_retention_limit = var.snapshot_retention_limit
  daily_snapshot_time      = local.daily_snapshot_time

  dynamic "cache_usage_limits" {
    for_each = local.data_storage_limited || local.ecpu_limited ? [1] : []
    content {
      dynamic "data_storage" {
        for_each = local.data_storage_limited ? [1] : []
        content {
          minimum = var.data_storage_minimum_gb
          maximum = var.data_storage_maximum_gb
          unit    = "GB"
        }
      }
      dynamic "ecpu_per_second" {
        for_each = local.ecpu_limited ? [1] : []
        content {
          minimum = var.ecpu_minimum
          maximum = var.ecpu_maximum
        }
      }
    }
  }

  tags = local.common_tags
}

resource "awscc_elasticache_serverless_cache" "public" {
  count = local.public ? 1 : 0

  engine                = "valkey"
  serverless_cache_name = var.cache_name
  description           = "${var.cache_name} Valkey serverless cache"
  major_engine_version  = var.engine_version
  connection_type       = "public"
  network_type          = var.network_type
  # Public caches only accept IAM-authenticated users: every link user of this group is one.
  user_group_id = aws_elasticache_user_group.cache.user_group_id
  kms_key_id    = local.kms_key_arn

  snapshot_retention_limit = var.snapshot_retention_limit
  daily_snapshot_time      = local.daily_snapshot_time

  cache_usage_limits = local.data_storage_limited || local.ecpu_limited ? {
    data_storage = local.data_storage_limited ? {
      minimum = var.data_storage_minimum_gb
      maximum = var.data_storage_maximum_gb
      unit    = "GB"
    } : null
    ecpu_per_second = local.ecpu_limited ? {
      minimum = var.ecpu_minimum
      maximum = var.ecpu_maximum
    } : null
  } : null

  tags = [for key, value in local.common_tags : { key = key, value = value }]
}
