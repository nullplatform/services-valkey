locals {
  endpoint   = local.public ? awscc_elasticache_serverless_cache.public[0].endpoint : aws_elasticache_serverless_cache.cache[0].endpoint[0]
  valkey_arn = local.public ? awscc_elasticache_serverless_cache.public[0].arn : aws_elasticache_serverless_cache.cache[0].arn
  cache_name = local.public ? awscc_elasticache_serverless_cache.public[0].serverless_cache_name : aws_elasticache_serverless_cache.cache[0].name
}

output "endpoint" {
  value       = local.endpoint.address
  description = "Hostname applications connect to"
}

output "port" {
  value       = tostring(local.endpoint.port)
  description = "Port applications connect to, over TLS"
}

output "valkey_arn" {
  value       = local.valkey_arn
  description = "ARN of the serverless cache"
}

output "user_group_id" {
  value       = aws_elasticache_user_group.cache.user_group_id
  description = "User group every link user is added to"
}

output "cache_name" {
  value       = local.cache_name
  description = "Cache name, persisted in the service attributes so later actions reuse it"
}

output "connection_type" {
  value       = var.connection_type
  description = "vpc or public, persisted so links know whether to create password or IAM users"
}
