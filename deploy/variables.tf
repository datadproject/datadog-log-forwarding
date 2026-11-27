variable "environment_tag" {
  type        = string
  description = "development, test or production. Becomes env:<value> on forwarded logs."
}

variable "aws_account_id" {
  type        = string
  description = "AWS account this environment lives in. The provider refuses any other account."
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region of the log groups."
}

variable "assume_role_arn" {
  type        = string
  default     = null
  description = "Optional IAM role to assume in the target account (for example from a CI account)."
}

variable "dd_site" {
  type        = string
  default     = "ddog-gov.com"
  description = "Datadog site."
}

variable "dd_api_key_secret_name" {
  type        = string
  description = "Secrets Manager secret name (plain text) holding the Datadog API key, in this account."
}

variable "dd_api_key_kms_key_arn" {
  type        = string
  default     = null
  description = "Customer-managed KMS key encrypting the secret, if any."
}

variable "dd_tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags added to every forwarded log."
}

variable "dd_forwarder_layer_version" {
  type        = string
  default     = "119"
  description = "Datadog Forwarder layer version."
}

variable "dd_forwarder_subnet_ids" {
  type        = list(string)
  default     = []
  description = "Private subnets for the Forwarder."
}

variable "dd_forwarder_security_group_ids" {
  type        = list(string)
  default     = []
  description = "Security groups for the Forwarder."
}

variable "dd_proxy_https" {
  type        = string
  default     = null
  description = "Proxy URL for reaching Datadog."
}

variable "dd_proxy_no_proxy" {
  type        = list(string)
  default     = []
  description = "Hosts that bypass the proxy."
}

variable "dd_forwarder_skip_ssl_validation" {
  type        = bool
  default     = false
  description = "Skip TLS validation (Datadog recommends true behind a proxy)."
}

variable "dd_forwarder_reserved_concurrency" {
  type        = number
  default     = null
  description = "Reserved concurrency for the Forwarder."
}

variable "log_group_names" {
  type        = list(string)
  default     = []
  description = "Exact log group names to forward."
}

variable "log_group_name_prefixes" {
  type        = list(string)
  default     = []
  description = "Forward every log group starting with one of these prefixes."
}

variable "exclude_log_group_names" {
  type        = list(string)
  default     = []
  description = "Log groups to skip."
}

variable "filter_pattern" {
  type        = string
  default     = ""
  description = "Filter pattern for all groups. Empty forwards everything."
}

variable "filter_pattern_overrides" {
  type        = map(string)
  default     = {}
  description = "Per-log-group filter patterns."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Extra AWS tags for all resources."
}
