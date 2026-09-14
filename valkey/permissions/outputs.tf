output "user_name" {
  value       = aws_elasticache_user.link.user_name
  description = "Valkey user created for this link"
}

output "user_password" {
  value       = random_password.link.result
  sensitive   = true
  description = "Password of the link user"
}
