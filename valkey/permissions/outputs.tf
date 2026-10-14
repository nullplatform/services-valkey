output "user_name" {
  value       = local.user ? aws_elasticache_user.link[0].user_name : ""
  description = "Valkey user created for this link, empty when the cache has no access control"
}

output "user_password" {
  value       = local.password ? random_password.link[0].result : ""
  sensitive   = true
  description = "Password of the link user, empty for an IAM link or a cache with no access control"
}

output "auth_mode" {
  value       = var.auth_mode
  description = "password, iam or none"
}

output "access_key_id" {
  value       = local.iam ? aws_iam_access_key.link[0].id : ""
  description = "Access key of the link's IAM user, empty for a password link"
}

output "secret_access_key" {
  value       = local.iam ? aws_iam_access_key.link[0].secret : ""
  sensitive   = true
  description = "Secret of the link's IAM user, empty for a password link"
}
