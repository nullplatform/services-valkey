resource "aws_iam_role" "nullplatform_valkey" {
  count = local.iam_create ? 1 : 0

  name        = local.role_name
  description = "Permissions role assumed by the nullplatform agent role for the serverless-valkey service"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = concat([local.agent_role_arn], var.additional_agent_role_arns) }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.iam_default_tags
}

resource "aws_iam_policy" "nullplatform_valkey" {
  count = local.iam_create ? 1 : 0

  name        = "${local.policies_name_prefix}_valkey_policy"
  description = "ElastiCache serverless cache, user group and user management for the nullplatform serverless-valkey service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ManageCaches"
        Effect   = "Allow"
        Action   = ["elasticache:*"]
        Resource = local.managed_elasticache_arns
      },
      {
        Sid    = "ManageUserGroupMembership"
        Effect = "Allow"
        Action = [
          "elasticache:CreateUserGroup",
          "elasticache:ModifyUserGroup",
          "elasticache:DeleteUserGroup",
        ]
        Resource = local.all_elasticache_users_arn
      },
      {
        Sid    = "BindCachesToUserGroups"
        Effect = "Allow"
        Action = [
          "elasticache:CreateServerlessCache",
          "elasticache:ModifyServerlessCache",
        ]
        Resource = local.all_elasticache_usergroups_arn
      },
      {
        Sid    = "AccountLevelReads"
        Effect = "Allow"
        Action = [
          "elasticache:Describe*",
          "elasticache:ListTagsForResource",
        ]
        Resource = "*"
      },
      {
        Sid      = "CreateServiceLinkedRole"
        Effect   = "Allow"
        Action   = ["iam:CreateServiceLinkedRole"]
        Resource = local.elasticache_service_linked_role_arn
        Condition = {
          StringLike = { "iam:AWSServiceName" = "elasticache.amazonaws.com" }
        }
      },
      {
        # Public caches are created through Cloud Control (the awscc provider). Cloud Control
        # calls ElastiCache with the caller's own permissions, so the statements above still apply.
        Sid    = "ManagePublicCachesThroughCloudControl"
        Effect = "Allow"
        Action = [
          "cloudformation:CreateResource",
          "cloudformation:GetResource",
          "cloudformation:UpdateResource",
          "cloudformation:DeleteResource",
          "cloudformation:GetResourceRequestStatus",
          "cloudformation:ListResources",
        ]
        Resource = "*"
      },
      {
        Sid      = "EncryptCachesWithCustomerManagedKeys"
        Effect   = "Allow"
        Action   = ["kms:CreateGrant", "kms:DescribeKey"]
        Resource = "*"
        Condition = {
          StringLike = { "kms:ViaService" = "elasticache.*.amazonaws.com" }
        }
      },
      {
        # Links to a public cache authenticate with IAM: each gets its own IAM user and access key.
        # The users live under their own path, so no other np-* user (another service's links)
        # is in reach, and each must carry the link boundary, which caps it at elasticache:Connect
        # whatever inline policy it is given.
        Sid      = "CreateBoundedLinkIamUsers"
        Effect   = "Allow"
        Action   = ["iam:CreateUser", "iam:PutUserPolicy"]
        Resource = local.link_users_arn
        Condition = {
          StringEquals = { "iam:PermissionsBoundary" = local.link_boundary_arn }
        }
      },
      {
        Sid    = "ManageLinkIamUsers"
        Effect = "Allow"
        Action = [
          "iam:DeleteUser",
          "iam:GetUser",
          "iam:TagUser",
          "iam:UntagUser",
          "iam:ListUserTags",
          "iam:GetUserPolicy",
          "iam:DeleteUserPolicy",
          "iam:ListUserPolicies",
          "iam:ListAttachedUserPolicies",
          "iam:ListGroupsForUser",
          "iam:CreateAccessKey",
          "iam:DeleteAccessKey",
          "iam:ListAccessKeys",
        ]
        Resource = local.link_users_arn
      },
      {
        Sid    = "KeepTheLinkBoundary"
        Effect = "Deny"
        Action = [
          "iam:DeleteUserPermissionsBoundary",
          "iam:PutUserPermissionsBoundary",
        ]
        Resource = local.link_users_arn
      },
    ]
  })

  tags = local.iam_default_tags
}

resource "aws_iam_policy" "nullplatform_valkey_state" {
  count = local.iam_create ? 1 : 0

  name        = "${local.policies_name_prefix}_valkey_state_policy"
  description = "Terraform state bucket management for the nullplatform serverless-valkey service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # No prefix condition on purpose: HeadBucket (build_context) sends no prefix, and the
        # S3 backend lists env:/ to find workspaces. Object access below stays under services/valkey/.
        Sid    = "ListStateBucket"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:ListBucketVersions",
          "s3:GetBucketLocation",
        ]
        Resource = "arn:aws:s3:::${var.state_bucket_name}"
      },
      {
        Sid    = "ManageStateObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion",
        ]
        Resource = "arn:aws:s3:::${var.state_bucket_name}/services/valkey/*"
      },
    ]
  })

  tags = local.iam_default_tags
}

resource "aws_iam_role_policy_attachment" "valkey" {
  count = local.iam_create ? 1 : 0

  role       = aws_iam_role.nullplatform_valkey[0].name
  policy_arn = aws_iam_policy.nullplatform_valkey[0].arn
}

resource "aws_iam_role_policy_attachment" "valkey_state" {
  count = local.iam_create ? 1 : 0

  role       = aws_iam_role.nullplatform_valkey[0].name
  policy_arn = aws_iam_policy.nullplatform_valkey_state[0].arn
}

# Caps every link IAM user at elasticache:Connect: the permissions role may only create link users
# that carry it, so it cannot hand out broader access through their inline policies.
resource "aws_iam_policy" "link_boundary" {
  count = local.iam_create ? 1 : 0

  name        = local.link_boundary_name
  path        = local.link_iam_path
  description = "Permissions boundary of the IAM users created for links to public nullplatform serverless-valkey caches"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ConnectOnly"
      Effect   = "Allow"
      Action   = "elasticache:Connect"
      Resource = "*"
    }]
  })

  tags = local.iam_default_tags
}
