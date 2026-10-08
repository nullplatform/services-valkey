locals {
  iam = var.auth_mode == "iam"

  # Must match specs/requirements/aws: the permissions role may only create link users under this
  # path, and only with this boundary, which caps them at elasticache:Connect.
  link_iam_path     = "/nullplatform/valkey/"
  link_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy${local.link_iam_path}np-valkey-link-boundary"
}
