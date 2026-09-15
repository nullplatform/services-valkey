output "endpoint" {
  value       = aws_elasticache_serverless_cache.cache.endpoint[0].address
  description = "Hostname applications connect to"
}

output "port" {
  value       = aws_elasticache_serverless_cache.cache.endpoint[0].port
  description = "Port applications connect to, over TLS"
}

output "valkey_arn" {
  value       = aws_elasticache_serverless_cache.cache.arn
  description = "ARN of the serverless cache"
}

output "user_group_id" {
  value       = aws_elasticache_user_group.cache.user_group_id
  description = "User group every link user is added to"
}

output "cache_name" {
  value       = aws_elasticache_serverless_cache.cache.name
  description = "Cache name, persisted in the service attributes so later actions reuse it"
}
