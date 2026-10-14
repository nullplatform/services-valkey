################################################################################
# Install: registers the Serverless Valkey service definition (service and link
# specifications) and its agent association (the notification channel that
# routes the service's actions to an agent) on a nullplatform account.
#
# This is a reference to copy into your own infrastructure, not a module to
# apply from here: it declares no provider. Configure the nullplatform provider
# in the root module that uses it.
#
# The IAM role the agent assumes lives in ../../requirements/aws and is applied
# separately, in the AWS account that holds the caches.
################################################################################

locals {
  service_path    = "valkey"
  available_links = ["connect"]
}

module "service_definition" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition?ref=v8.1.0"

  nrn                    = var.nrn
  service_name           = var.service_name
  service_path           = local.service_path
  available_links        = local.available_links
  repository_org         = var.repository_org
  repository_name        = var.repository_name
  repository_branch      = var.repository_branch
  repository_ref_type    = var.repository_ref_type
  repository_token       = var.repository_token
  extra_visibile_to_nrns = var.extra_visible_to_nrns
  dimensions             = var.dimensions
}

module "service_definition_agent_association" {
  source = "git::https://github.com/nullplatform/tofu-modules.git//nullplatform/service_definition_agent_association?ref=v8.1.0"

  nrn                          = var.nrn
  api_key                      = var.np_api_key
  tags_selectors               = var.tags_selectors
  service_specification_slug   = module.service_definition.service_specification_slug
  repository_service_spec_repo = var.repository_name
  service_path                 = local.service_path
  base_clone_path              = var.base_clone_path
  description                  = "Serverless Valkey service actions"
  # telemetry routes the metric notifications to the agent: without it the service shows no metrics.
  channel_sources = ["service", "telemetry"]
}
