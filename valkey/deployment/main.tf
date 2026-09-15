locals {
  common_tags = merge(var.tags, {
    "managed-by" = "nullplatform"
    "service-id" = var.service_id
  })

  subnet_ids = compact([for s in split(",", var.subnet_ids) : trimspace(s)])
}

data "aws_vpc" "cache" {
  id = var.vpc_id
}

resource "aws_security_group" "cache" {
  name        = "${var.cache_name}-security-group"
  description = "Valkey access for ${var.cache_name} from inside the VPC"
  vpc_id      = var.vpc_id

  ingress {
    description = "Valkey from the VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.cache.cidr_block]
  }

  egress {
    description = "All outbound inside the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.aws_vpc.cache.cidr_block]
  }

  tags = local.common_tags
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
  engine               = "valkey"
  name                 = var.cache_name
  description          = "${var.cache_name} Valkey serverless cache"
  major_engine_version = "8"
  user_group_id        = aws_elasticache_user_group.cache.user_group_id
  security_group_ids   = [aws_security_group.cache.id]
  subnet_ids           = local.subnet_ids

  tags = local.common_tags
}
