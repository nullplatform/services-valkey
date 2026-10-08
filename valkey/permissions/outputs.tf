output "user_name" {
  value       = aws_elasticache_user.link.user_name
  description = "Valkey user created for this link"
}

output "user_password" {
  value       = local.iam ? "" : random_password.link.result
  sensitive   = true
  description = "Password of the link user, empty for an IAM link"
}

output "auth_mode" {
  value       = var.auth_mode
  description = "password or iam"
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
