output "forwarder_arn" {
  description = "ARN of the Datadog Forwarder Lambda."
  value       = aws_lambda_function.dd_forwarder.arn
}

output "forwarder_function_name" {
  description = "Name of the Datadog Forwarder Lambda."
  value       = aws_lambda_function.dd_forwarder.function_name
}

output "forwarder_role_arn" {
  description = "IAM role used by the Forwarder."
  value       = aws_iam_role.dd_forwarder.arn
}

output "forwarder_layer_arn" {
  description = "Datadog Forwarder layer in use."
  value       = local.dd_forwarder_layer_arn
}

output "subscribed_log_groups" {
  description = "Log groups now forwarding to Datadog."
  value       = sort(tolist(local.dd_forwarder_target_log_groups))
}
