output "forwarder_arn" {
  value = module.datadog_log_forwarding.forwarder_arn
}

output "subscribed_log_groups" {
  value = module.datadog_log_forwarding.subscribed_log_groups
}
