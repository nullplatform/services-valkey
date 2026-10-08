data "aws_caller_identity" "current" {}

resource "random_password" "link" {
  length  = 32
  special = false
}

# A VPC cache authenticates its link users with a password. A public cache only accepts
# IAM-authenticated users: the application signs a token with the link's IAM user instead.
resource "aws_elasticache_user" "link" {
  user_id       = var.user_name
  user_name     = var.user_name
  engine        = "valkey"
  access_string = "on ~* +@all"
  passwords     = local.iam ? null : [random_password.link.result]

  dynamic "authentication_mode" {
    for_each = local.iam ? [1] : []
    content {
      type = "iam"
    }
  }

  tags = {
    "managed-by" = "nullplatform"
    "link-id"    = var.link_id
  }
}

resource "aws_elasticache_user_group_association" "link" {
  user_group_id = var.user_group_id
  user_id       = aws_elasticache_user.link.user_id
}

resource "aws_iam_user" "link" {
  count = local.iam ? 1 : 0

  name                 = var.user_name
  path                 = local.link_iam_path
  permissions_boundary = local.link_boundary_arn

  tags = {
    "managed-by" = "nullplatform"
    "link-id"    = var.link_id
  }
}

resource "aws_iam_user_policy" "link" {
  count = local.iam ? 1 : 0

  name = "${var.user_name}-connect"
  user = aws_iam_user.link[0].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ConnectAsLinkUser"
      Effect   = "Allow"
      Action   = "elasticache:Connect"
      Resource = [var.cache_arn, aws_elasticache_user.link.arn]
    }]
  })
}

resource "aws_iam_access_key" "link" {
  count = local.iam ? 1 : 0

  user = aws_iam_user.link[0].name
}
