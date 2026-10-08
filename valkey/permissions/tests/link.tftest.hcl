# Evaluates the module against mocked providers: no credentials, nothing created.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111122223333" }
  }
  mock_resource "aws_elasticache_user" {
    defaults = { arn = "arn:aws:elasticache:us-west-2:111122223333:user:np-orders-api-7d9e2-user" }
  }
  mock_resource "aws_iam_access_key" {
    defaults = { id = "AKIAEXAMPLE", secret = "secret-example" }
  }
}

mock_provider "random" {
  mock_resource "random_password" {
    defaults = { result = "abcdefghijklmnopqrstuvwxyz012345" }
  }
}

variables {
  link_id       = "link-1"
  region        = "us-west-2"
  user_group_id = "np-my-cache-0f3a6-ug"
  user_name     = "np-orders-api-7d9e2-user"
}

run "password_user_by_default" {
  assert {
    condition     = length(aws_elasticache_user.link.passwords) == 1 && length(aws_elasticache_user.link.authentication_mode) == 0
    error_message = "a VPC cache link gets a password user"
  }
  assert {
    condition     = length(aws_iam_user.link) == 0 && length(aws_iam_access_key.link) == 0
    error_message = "a password link creates no IAM user"
  }
  assert {
    condition     = output.access_key_id == "" && output.secret_access_key == ""
    error_message = "a password link has no access key"
  }
}

run "iam_user_for_a_public_cache" {
  variables {
    auth_mode = "iam"
    cache_arn = "arn:aws:elasticache:us-west-2:111122223333:serverlesscache:np-my-cache-0f3a6"
  }
  assert {
    condition     = aws_elasticache_user.link.passwords == null && aws_elasticache_user.link.authentication_mode[0].type == "iam"
    error_message = "a public cache link gets an IAM-authenticated user with no password"
  }
  assert {
    condition     = aws_elasticache_user.link.user_id == aws_elasticache_user.link.user_name
    error_message = "IAM authentication needs the user id to equal the user name"
  }
  assert {
    condition     = aws_iam_user.link[0].name == "np-orders-api-7d9e2-user" && aws_iam_user.link[0].tags["link-id"] == "link-1"
    error_message = "the link gets its own IAM user, tagged with the link"
  }
  assert {
    condition = (
      aws_iam_user.link[0].path == "/nullplatform/valkey/" &&
      aws_iam_user.link[0].permissions_boundary == "arn:aws:iam::111122223333:policy/nullplatform/valkey/np-valkey-link-boundary"
    )
    error_message = "the IAM user lives under the link path and carries the boundary the permissions role requires"
  }
  assert {
    condition = (
      jsondecode(aws_iam_user_policy.link[0].policy).Statement[0].Action == "elasticache:Connect" &&
      jsondecode(aws_iam_user_policy.link[0].policy).Statement[0].Resource == [
        "arn:aws:elasticache:us-west-2:111122223333:serverlesscache:np-my-cache-0f3a6",
        "arn:aws:elasticache:us-west-2:111122223333:user:np-orders-api-7d9e2-user",
      ]
    )
    error_message = "the IAM user may only connect to this cache as this link's user"
  }
  assert {
    condition     = output.access_key_id == "AKIAEXAMPLE" && output.secret_access_key == "secret-example"
    error_message = "the access key is handed to the link"
  }
}

run "iam_requires_the_cache_arn" {
  command = plan
  variables {
    auth_mode = "iam"
  }
  expect_failures = [var.cache_arn]
}

run "rejects_an_unknown_auth_mode" {
  command = plan
  variables {
    auth_mode = "token"
  }
  expect_failures = [var.auth_mode]
}
