locals {
  iam_module_name = "requirements-valkey"

  iam_create = var.iam_create_role

  role_name            = var.role_name != "" ? var.role_name : "nullplatform_${var.cluster_name}_valkey_role"
  policies_name_prefix = var.policies_name_prefix != "" ? var.policies_name_prefix : "nullplatform_${var.cluster_name}"

  account_id = data.aws_caller_identity.current.account_id

  agent_role_arn = var.agent_role_arn != "" ? var.agent_role_arn : "arn:aws:iam::${local.account_id}:role/nullplatform-${var.cluster_name}-agent-role"

  managed_elasticache_arns = [
    "arn:aws:elasticache:*:${local.account_id}:serverlesscache:${var.cache_name_prefix}*",
    "arn:aws:elasticache:*:${local.account_id}:usergroup:${var.cache_name_prefix}*",
    "arn:aws:elasticache:*:${local.account_id}:user:${var.cache_name_prefix}*",
  ]

  all_elasticache_users_arn      = "arn:aws:elasticache:*:${local.account_id}:user:*"
  all_elasticache_usergroups_arn = "arn:aws:elasticache:*:${local.account_id}:usergroup:*"

  vpc_endpoint_create_arns = [
    "arn:aws:ec2:*:${local.account_id}:vpc-endpoint/*",
    "arn:aws:ec2:*:${local.account_id}:vpc/*",
    "arn:aws:ec2:*:${local.account_id}:subnet/*",
    "arn:aws:ec2:*:${local.account_id}:security-group/*",
    "arn:aws:ec2:*:${local.account_id}:route-table/*",
  ]

  elasticache_service_linked_role_arn = "arn:aws:iam::${local.account_id}:role/aws-service-role/elasticache.amazonaws.com/AWSServiceRoleForElastiCache"

  iam_default_tags = merge(var.iam_resource_tags_json, {
    ManagedBy = "nullplatform-custom-scope-role"
    Module    = local.iam_module_name
  })
}
