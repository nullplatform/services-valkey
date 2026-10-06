output "permissions_role_arn" {
  description = "ARN of the role the agent assumes to operate this service. Publish it to the nullplatform AWS IAM provider under selector \"valkey\"."
  value       = local.iam_create ? aws_iam_role.nullplatform_valkey[0].arn : ""
}

output "permissions_role_name" {
  description = "Name of the permissions role"
  value       = local.iam_create ? aws_iam_role.nullplatform_valkey[0].name : ""
}

output "permissions_role_id" {
  description = "ID of the permissions role"
  value       = local.iam_create ? aws_iam_role.nullplatform_valkey[0].id : ""
}

output "metrics_policy_arn" {
  description = "ARN of the CloudWatch read policy attached to the agent roles for the service metrics"
  value       = local.attach_metrics_policy ? aws_iam_policy.nullplatform_valkey_metrics[0].arn : ""
}
