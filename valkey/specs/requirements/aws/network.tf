resource "aws_iam_policy" "nullplatform_valkey_network" {
  count = local.iam_create ? 1 : 0

  name        = "${local.policies_name_prefix}_valkey_network_policy"
  description = "Security group management for the nullplatform serverless-valkey service"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CreateSecurityGroupInVpc"
        Effect   = "Allow"
        Action   = ["ec2:CreateSecurityGroup"]
        Resource = "arn:aws:ec2:*:${local.account_id}:vpc/*"
      },
      {
        Sid      = "CreateTaggedSecurityGroup"
        Effect   = "Allow"
        Action   = ["ec2:CreateSecurityGroup"]
        Resource = "arn:aws:ec2:*:${local.account_id}:security-group/*"
        Condition = {
          StringEquals = { "aws:RequestTag/managed-by" = "nullplatform" }
        }
      },
      {
        Sid      = "TagSecurityGroupOnCreate"
        Effect   = "Allow"
        Action   = ["ec2:CreateTags"]
        Resource = "arn:aws:ec2:*:${local.account_id}:security-group/*"
        Condition = {
          StringEquals = { "ec2:CreateAction" = "CreateSecurityGroup" }
        }
      },
      {
        Sid    = "ManageOwnSecurityGroups"
        Effect = "Allow"
        Action = [
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateTags",
          "ec2:DeleteTags",
        ]
        Resource = "arn:aws:ec2:*:${local.account_id}:security-group/*"
        Condition = {
          StringEquals = { "aws:ResourceTag/managed-by" = "nullplatform" }
        }
      },
      {
        Sid    = "DescribeNetwork"
        Effect = "Allow"
        Action = [
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcAttribute",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeNetworkInterfaces",
        ]
        Resource = "*"
      },
    ]
  })

  tags = local.iam_default_tags
}

resource "aws_iam_role_policy_attachment" "valkey_network" {
  count = local.iam_create ? 1 : 0

  role       = aws_iam_role.nullplatform_valkey[0].name
  policy_arn = aws_iam_policy.nullplatform_valkey_network[0].arn
}
