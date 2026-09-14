resource "random_password" "link" {
  length  = 32
  special = false
}

resource "aws_elasticache_user" "link" {
  user_id       = var.user_name
  user_name     = var.user_name
  engine        = "valkey"
  access_string = "on ~* +@all"
  passwords     = [random_password.link.result]

  tags = {
    "managed-by" = "nullplatform"
    "link-id"    = var.link_id
  }
}

resource "aws_elasticache_user_group_association" "link" {
  user_group_id = var.user_group_id
  user_id       = aws_elasticache_user.link.user_id
}
