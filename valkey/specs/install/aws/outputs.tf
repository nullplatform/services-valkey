output "service_specification_id" {
  description = "ID of the registered Serverless Valkey service specification."
  value       = module.service_definition.service_specification_id
}

output "service_specification_slug" {
  description = "Slug of the registered Serverless Valkey service specification."
  value       = module.service_definition.service_specification_slug
}

output "notification_channel_id" {
  description = "ID of the notification channel routing this service's actions to the agent."
  value       = module.service_definition_agent_association.id
}
