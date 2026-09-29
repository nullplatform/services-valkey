resource "aws_iam_policy" "nullplatform_valkey_kms" {
  count = local.iam_create ? 1 : 0

  name        = "${local.policies_name_prefix}_valkey_kms_policy"
  description = "Dedicated KMS key management for the nullplatform serverless-valkey service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CreateOwnKey"
        Effect   = "Allow"
        Action   = "kms:CreateKey"
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestTag/managed-by" = "nullplatform" }
        }
      },
      {
        Sid    = "ManageOwnKey"
        Effect = "Allow"
        Action = [
          "kms:TagResource",
          "kms:UntagResource",
          "kms:DescribeKey",
          "kms:GetKeyPolicy",
          "kms:GetKeyRotationStatus",
          "kms:EnableKeyRotation",
          "kms:ListResourceTags",
          "kms:ScheduleKeyDeletion",
          "kms:CancelKeyDeletion",
          "kms:CreateGrant",
          "kms:ListGrants",
          "kms:RevokeGrant",
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:UpdateAlias",
        ]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:ResourceTag/managed-by" = "nullplatform" }
        }
      },
      {
        Sid    = "ManageOwnAlias"
        Effect = "Allow"
        Action = [
          "kms:CreateAlias",
          "kms:DeleteAlias",
          "kms:UpdateAlias",
        ]
        Resource = "arn:aws:kms:*:${local.account_id}:alias/nullplatform-valkey-*"
      },
      {
        Sid      = "ListAliases"
        Effect   = "Allow"
        Action   = "kms:ListAliases"
        Resource = "*"
      },
    ]
  })

  tags = local.iam_default_tags
}

resource "aws_iam_policy" "nullplatform_valkey_external_kms" {
  count = local.iam_create && length(var.external_kms_key_arns) > 0 ? 1 : 0

  name        = "${local.policies_name_prefix}_valkey_external_kms_policy"
  description = "Use of existing KMS keys passed to the nullplatform serverless-valkey service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DescribeExternalKey"
        Effect   = "Allow"
        Action   = "kms:DescribeKey"
        Resource = var.external_kms_key_arns
      },
      {
        Sid      = "GrantExternalKeyToElastiCache"
        Effect   = "Allow"
        Action   = "kms:CreateGrant"
        Resource = var.external_kms_key_arns
        Condition = {
          Bool = { "kms:GrantIsForAWSResource" = "true" }
        }
      },
    ]
  })

  tags = local.iam_default_tags
}

resource "aws_iam_role_policy_attachment" "valkey_kms" {
  count = local.iam_create ? 1 : 0

  role       = aws_iam_role.nullplatform_valkey[0].name
  policy_arn = aws_iam_policy.nullplatform_valkey_kms[0].arn
}

resource "aws_iam_role_policy_attachment" "valkey_external_kms" {
  count = local.iam_create && length(var.external_kms_key_arns) > 0 ? 1 : 0

  role       = aws_iam_role.nullplatform_valkey[0].name
  policy_arn = aws_iam_policy.nullplatform_valkey_external_kms[0].arn
}
