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
    Statement = [{
      Sid    = "ManageStateBuckets"
      Effect = "Allow"
      Action = ["s3:*"]
      Resource = [
        "arn:aws:s3:::np-service-*",
        "arn:aws:s3:::np-service-*/*",
      ]
    }]
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
