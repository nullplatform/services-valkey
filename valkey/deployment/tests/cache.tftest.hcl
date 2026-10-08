# Evaluates the module against mocked providers: no credentials, nothing created.
mock_provider "aws" {
  mock_data "aws_vpc" {
    defaults = { cidr_block = "10.0.0.0/16", ipv6_cidr_block_associations = [] }
  }
  mock_resource "aws_security_group" {
    defaults = { id = "sg-own" }
  }
  mock_resource "aws_kms_key" {
    defaults = { arn = "arn:aws:kms:us-west-2:111122223333:key/own", key_id = "own" }
  }
  mock_resource "aws_elasticache_serverless_cache" {
    defaults = {
      arn      = "arn:aws:elasticache:us-west-2:111122223333:serverlesscache:np-my-cache-0f3a6"
      endpoint = [{ address = "vpc.cache.amazonaws.com", port = 6379 }]
    }
  }
}

mock_provider "awscc" {
  mock_resource "awscc_elasticache_serverless_cache" {
    defaults = {
      arn      = "arn:aws:elasticache:us-west-2:111122223333:serverlesscache:np-my-cache-0f3a6"
      endpoint = { address = "public.cache.amazonaws.com", port = "6379" }
    }
  }
}

variables {
  service_id = "svc-1"
  region     = "us-west-2"
  cache_name = "np-my-cache-0f3a6"
  vpc_id     = "vpc-0123"
  subnet_ids = ["subnet-a", "subnet-b"]
}

run "vpc_defaults" {
  assert {
    condition     = length(aws_elasticache_serverless_cache.cache) == 1 && length(awscc_elasticache_serverless_cache.public) == 0
    error_message = "a VPC cache is created with the aws provider only"
  }
  assert {
    condition     = aws_elasticache_serverless_cache.cache[0].major_engine_version == "9" && aws_elasticache_serverless_cache.cache[0].network_type == "ipv4"
    error_message = "defaults: Valkey 9 over IPv4"
  }
  assert {
    condition     = aws_elasticache_serverless_cache.cache[0].kms_key_id == "arn:aws:kms:us-west-2:111122223333:key/own" && length(aws_kms_key.cache) == 1 && aws_elasticache_serverless_cache.cache[0].snapshot_retention_limit == 0
    error_message = "defaults: a dedicated KMS key for the cache and no automatic backups"
  }
  assert {
    condition     = length(aws_elasticache_serverless_cache.cache[0].cache_usage_limits) == 0
    error_message = "no usage limits unless one is set"
  }
  assert {
    condition     = aws_elasticache_serverless_cache.cache[0].security_group_ids == toset(["sg-own"]) && aws_elasticache_serverless_cache.cache[0].subnet_ids == toset(["subnet-a", "subnet-b"])
    error_message = "the cache sits in the given subnets behind its own security group"
  }
  assert {
    condition     = length(aws_security_group.cache) == 1 && aws_elasticache_serverless_cache.cache[0].tags["managed-by"] == "nullplatform"
    error_message = "the security group is created and the cache is tagged as managed by nullplatform"
  }
  assert {
    condition     = output.endpoint == "vpc.cache.amazonaws.com" && output.port == "6379" && output.connection_type == "vpc"
    error_message = "the outputs come from the VPC cache"
  }
}

run "vpc_customized" {
  variables {
    engine_version           = "8"
    network_type             = "dual_stack"
    kms_key_arn              = "arn:aws:kms:us-west-2:111122223333:key/abc"
    security_group_ids       = ["sg-extra"]
    snapshot_retention_limit = 7
    daily_snapshot_time      = "04:30"
    data_storage_maximum_gb  = 10
    ecpu_minimum             = 1000
    ecpu_maximum             = 5000
  }
  assert {
    condition     = aws_elasticache_serverless_cache.cache[0].security_group_ids == toset(["sg-extra"]) && length(aws_security_group.cache) == 0
    error_message = "the selected security groups replace the default one, which is then not created"
  }
  assert {
    condition     = aws_elasticache_serverless_cache.cache[0].kms_key_id == "arn:aws:kms:us-west-2:111122223333:key/abc" && length(aws_kms_key.cache) == 0 && aws_elasticache_serverless_cache.cache[0].network_type == "dual_stack" && aws_elasticache_serverless_cache.cache[0].major_engine_version == "8"
    error_message = "an existing customer managed key replaces the dedicated one; the network type and engine reach the cache"
  }
  assert {
    condition     = aws_elasticache_serverless_cache.cache[0].snapshot_retention_limit == 7 && aws_elasticache_serverless_cache.cache[0].daily_snapshot_time == "04:30"
    error_message = "automatic backups keep 7 days and start at 04:30 UTC"
  }
  assert {
    condition = (
      aws_elasticache_serverless_cache.cache[0].cache_usage_limits[0].data_storage[0].maximum == 10 &&
      aws_elasticache_serverless_cache.cache[0].cache_usage_limits[0].data_storage[0].unit == "GB" &&
      aws_elasticache_serverless_cache.cache[0].cache_usage_limits[0].ecpu_per_second[0].minimum == 1000 &&
      aws_elasticache_serverless_cache.cache[0].cache_usage_limits[0].ecpu_per_second[0].maximum == 5000
    )
    error_message = "only the usage limits that are set reach the cache"
  }
}

run "vpc_without_ecpu_limits" {
  variables {
    data_storage_minimum_gb = 1
  }
  assert {
    condition     = length(aws_elasticache_serverless_cache.cache[0].cache_usage_limits[0].ecpu_per_second) == 0
    error_message = "the ECPU block is omitted when no ECPU limit is set"
  }
}

run "public" {
  variables {
    engine_version           = "9"
    connection_type          = "public"
    vpc_id                   = ""
    subnet_ids               = []
    security_group_ids       = ["sg-ignored"]
    snapshot_retention_limit = 3
    ecpu_maximum             = 5000
    tags                     = { team = "payments" }
  }
  assert {
    condition     = length(aws_elasticache_serverless_cache.cache) == 0 && length(awscc_elasticache_serverless_cache.public) == 1
    error_message = "a public cache is created with the awscc provider only"
  }
  assert {
    condition     = length(aws_security_group.cache) == 0
    error_message = "a public cache has no security group"
  }
  assert {
    condition = (
      awscc_elasticache_serverless_cache.public[0].connection_type == "public" &&
      awscc_elasticache_serverless_cache.public[0].major_engine_version == "9" &&
      awscc_elasticache_serverless_cache.public[0].user_group_id == "np-my-cache-0f3a6-ug" &&
      awscc_elasticache_serverless_cache.public[0].snapshot_retention_limit == 3
    )
    error_message = "the public cache gets the connection type, engine, user group and backups"
  }
  assert {
    condition     = awscc_elasticache_serverless_cache.public[0].cache_usage_limits.ecpu_per_second.maximum == 5000 && awscc_elasticache_serverless_cache.public[0].cache_usage_limits.data_storage == null
    error_message = "only the usage limits that are set reach the public cache"
  }
  assert {
    condition     = contains(awscc_elasticache_serverless_cache.public[0].tags, { key = "team", value = "payments" }) && contains(awscc_elasticache_serverless_cache.public[0].tags, { key = "managed-by", value = "nullplatform" })
    error_message = "the public cache carries the developer's tags and the platform's"
  }
  assert {
    condition     = output.endpoint == "public.cache.amazonaws.com" && output.port == "6379" && output.connection_type == "public"
    error_message = "the outputs come from the public cache"
  }
}

run "public_requires_valkey_9" {
  command = plan
  variables {
    engine_version  = "8"
    connection_type = "public"
  }
  expect_failures = [var.connection_type]
}

run "vpc_requires_subnets" {
  command = plan
  variables {
    subnet_ids = []
  }
  expect_failures = [var.subnet_ids]
}

run "rejects_an_unknown_network_type" {
  command = plan
  variables {
    network_type = "ipv5"
  }
  expect_failures = [var.network_type]
}

run "rejects_usage_limits_out_of_range" {
  command = plan
  variables {
    data_storage_maximum_gb = 5001
    ecpu_minimum            = 999
  }
  expect_failures = [var.data_storage_maximum_gb, var.ecpu_minimum]
}
