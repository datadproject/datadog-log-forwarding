module "datadog_log_forwarding" {
  source = "../modules/datadog-log-forwarding"

  environment_tag = var.environment_tag
  region          = var.aws_region

  dd_site                = var.dd_site
  dd_api_key_secret_name = var.dd_api_key_secret_name
  dd_api_key_kms_key_arn = var.dd_api_key_kms_key_arn
  dd_tags                = var.dd_tags

  dd_forwarder_layer_version        = var.dd_forwarder_layer_version
  dd_forwarder_subnet_ids           = var.dd_forwarder_subnet_ids
  dd_forwarder_security_group_ids   = var.dd_forwarder_security_group_ids
  dd_proxy_https                    = var.dd_proxy_https
  dd_proxy_no_proxy                 = var.dd_proxy_no_proxy
  dd_forwarder_skip_ssl_validation  = var.dd_forwarder_skip_ssl_validation
  dd_forwarder_reserved_concurrency = var.dd_forwarder_reserved_concurrency

  log_group_names          = var.log_group_names
  log_group_name_prefixes  = var.log_group_name_prefixes
  exclude_log_group_names  = var.exclude_log_group_names
  filter_pattern           = var.filter_pattern
  filter_pattern_overrides = var.filter_pattern_overrides
}
