# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------
variable "environment_tag" {
  type        = string
  description = "Environment name. Used in resource names and added to every forwarded log as env:<value> (for example development, test, production)."
}

variable "application" {
  type        = string
  default     = "perkins"
  description = "Application name. Used as the resource name prefix and added to every forwarded log as app:<value>."
}

variable "region" {
  type        = string
  description = "AWS region of the Forwarder and the log groups (for example us-east-1)."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "AWS tags for every resource this module creates."
}

# ---------------------------------------------------------------------------
# Datadog
# ---------------------------------------------------------------------------
variable "dd_site" {
  type        = string
  default     = "ddog-gov.com"
  description = "Datadog site the logs are sent to."
}

variable "dd_api_key_secret_name" {
  type        = string
  description = "Name of the Secrets Manager secret holding the Datadog API key as plain text, in this account."
}

variable "dd_api_key_kms_key_arn" {
  type        = string
  default     = null
  description = "Customer-managed KMS key that encrypts the API key secret, if any. Lets the Forwarder decrypt it."
}

variable "dd_tags" {
  type        = map(string)
  default     = {}
  description = "Extra tags added to every forwarded log, on top of env and app."
}

# ---------------------------------------------------------------------------
# Forwarder Lambda (same settings as the ECS cluster module)
# ---------------------------------------------------------------------------
variable "dd_forwarder_layer_version" {
  type        = string
  default     = "119"
  description = "Version of Datadog's Forwarder Lambda layer. 119 is the version in Datadog's current CloudFormation template."
}

variable "dd_forwarder_memory_size" {
  type        = number
  default     = 1024
  description = "Forwarder memory (MB)."
}

variable "dd_forwarder_timeout" {
  type        = number
  default     = 120
  description = "Forwarder timeout (seconds)."
}

variable "dd_forwarder_reserved_concurrency" {
  type        = number
  default     = null
  description = "Reserved concurrency for the Forwarder. Null uses unreserved account concurrency."
}

variable "dd_forwarder_log_retention_days" {
  type        = number
  default     = 90
  description = "Retention for the Forwarder's own CloudWatch log group."
}

variable "dd_forwarder_subnet_ids" {
  type        = list(string)
  default     = []
  description = "Private subnets to run the Forwarder in. Leave empty to run it outside a VPC."
}

variable "dd_forwarder_security_group_ids" {
  type        = list(string)
  default     = []
  description = "Security groups for the Forwarder. Required when subnets are set; must allow outbound HTTPS to the proxy."

  validation {
    condition     = length(var.dd_forwarder_subnet_ids) == 0 || length(var.dd_forwarder_security_group_ids) > 0
    error_message = "Set dd_forwarder_security_group_ids when dd_forwarder_subnet_ids is set."
  }
}

variable "dd_proxy_https" {
  type        = string
  default     = null
  description = "Proxy URL the Forwarder uses to reach Datadog (sets HTTP_PROXY and HTTPS_PROXY)."
}

variable "dd_proxy_no_proxy" {
  type        = list(string)
  default     = []
  description = "Hosts that bypass the proxy (sets NO_PROXY), for example VPC endpoint hostnames."
}

variable "dd_forwarder_skip_ssl_validation" {
  type        = bool
  default     = false
  description = "Skip TLS certificate validation. Datadog says to set this to true when sending through a proxy."
}

# ---------------------------------------------------------------------------
# Which log groups to forward
# ---------------------------------------------------------------------------
variable "log_group_names" {
  type        = list(string)
  default     = []
  description = "Exact CloudWatch log group names to forward. Plan fails if one of them does not exist, so typos are caught early."
}

variable "log_group_name_prefixes" {
  type        = list(string)
  default     = []
  description = "Forward every log group whose name starts with one of these prefixes, for example \"/aws/connect/\". Matches are looked up at plan time; run apply again to pick up log groups created later."
}

variable "exclude_log_group_names" {
  type        = list(string)
  default     = []
  description = "Log groups to skip even if they match a name or prefix above. The Forwarder's own log group is always skipped."
}

variable "filter_pattern" {
  type        = string
  default     = ""
  description = "CloudWatch Logs filter pattern for every subscribed log group. Empty string forwards every log event."
}

variable "filter_pattern_overrides" {
  type        = map(string)
  default     = {}
  description = "Per-log-group filter patterns, keyed by log group name. Overrides filter_pattern for that group."
}

variable "subscription_filter_name" {
  type        = string
  default     = "datadog-forwarder"
  description = "Name of the subscription filter on each log group."
}
