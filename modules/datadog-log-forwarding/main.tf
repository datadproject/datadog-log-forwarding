################################################################################
# DATADOG CLOUDWATCH LOG FORWARDER
# CloudWatch Logs -> Datadog Forwarder Lambda (in VPC, via proxy) -> Datadog
# Same pattern as the ECS cluster module, plus log group selection by name/prefix.
# Works in commercial AWS and GovCloud: the layer account follows the partition.
################################################################################

data "aws_partition" "dd_forwarder" {}
data "aws_caller_identity" "dd_forwarder" {}

data "aws_secretsmanager_secret" "dd_forwarder_api_key" {
  name = var.dd_api_key_secret_name
}

locals {
  account_id  = data.aws_caller_identity.dd_forwarder.account_id
  partition   = data.aws_partition.dd_forwarder.partition
  in_vpc      = length(var.dd_forwarder_subnet_ids) > 0
  common_tags = merge({ Application = var.application, Environment = var.environment_tag }, var.tags)

  dd_forwarder_function_name = substr("${var.application}-${var.environment_tag}-datadog-forwarder", 0, 64)
  dd_forwarder_log_group     = "/aws/lambda/${local.dd_forwarder_function_name}"

  # Datadog publishes the Forwarder layer from 464622532012 in commercial AWS
  # and from 002406178527 in GovCloud (same choice as Datadog's CloudFormation template).
  dd_layer_account = local.partition == "aws-us-gov" ? "002406178527" : "464622532012"

  dd_forwarder_layer_arn = format(
    "arn:%s:lambda:%s:%s:layer:Datadog-Forwarder:%s",
    local.partition,
    var.region,
    local.dd_layer_account,
    var.dd_forwarder_layer_version
  )

  dd_tags = join(",", [
    for k, v in merge({ env = var.environment_tag, app = var.application }, var.dd_tags) : "${k}:${v}"
  ])

  dd_forwarder_environment = {
    DD_SITE                      = var.dd_site
    DD_API_KEY_SECRET_ARN        = data.aws_secretsmanager_secret.dd_forwarder_api_key.arn
    DD_FORWARD_LOG               = "true"
    DD_TRACE_ENABLED             = "false"
    DD_ENHANCED_METRICS          = "false"
    DD_USE_VPC                   = local.in_vpc ? "true" : "false"
    DD_TAGS                      = local.dd_tags
    DD_FETCH_LAMBDA_TAGS         = "false"
    DD_FETCH_LOG_GROUP_TAGS      = "false"
    DD_FETCH_S3_TAGS             = "false"
    DD_FETCH_STEP_FUNCTIONS_TAGS = "false"
    DD_STORE_FAILED_EVENTS       = "false"
    DD_TAGS_CACHE_TTL_SECONDS    = "300"
    HTTP_PROXY                   = var.dd_proxy_https
    HTTPS_PROXY                  = var.dd_proxy_https
    NO_PROXY                     = length(var.dd_proxy_no_proxy) > 0 ? join(",", var.dd_proxy_no_proxy) : null
    DD_SKIP_SSL_VALIDATION       = tostring(var.dd_forwarder_skip_ssl_validation)
    DD_LOG_LEVEL                 = "INFO"
  }

  # Which log groups to subscribe: exact names + prefix matches, minus exclusions and the Forwarder itself.
  explicit_log_groups   = [for g in data.aws_cloudwatch_log_group.explicit : g.name]
  discovered_log_groups = flatten([for d in data.aws_cloudwatch_log_groups.by_prefix : d.log_group_names])

  dd_forwarder_target_log_groups = setsubtract(
    toset(concat(local.explicit_log_groups, local.discovered_log_groups)),
    toset(concat(var.exclude_log_group_names, [local.dd_forwarder_log_group]))
  )
}

# Exact names: looking each one up makes plan fail on a typo or a missing group.
data "aws_cloudwatch_log_group" "explicit" {
  for_each = toset(var.log_group_names)

  name = each.value
}

# Prefixes: every log group that currently matches.
data "aws_cloudwatch_log_groups" "by_prefix" {
  for_each = toset(var.log_group_name_prefixes)

  log_group_name_prefix = each.value
}

data "archive_file" "dd_forwarder_placeholder" {
  type        = "zip"
  output_path = "${path.root}/datadog-forwarder-placeholder.zip"

  source {
    filename = "placeholder.txt"
    content  = "Datadog Forwarder code is supplied by the Lambda layer."
  }
}

resource "aws_iam_role" "dd_forwarder" {
  name = "${local.dd_forwarder_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.dd_forwarder_function_name}-role" })
}

resource "aws_iam_role_policy_attachment" "dd_forwarder_basic" {
  role       = aws_iam_role.dd_forwarder.name
  policy_arn = format("arn:%s:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole", local.partition)
}

resource "aws_iam_role_policy_attachment" "dd_forwarder_vpc" {
  count = local.in_vpc ? 1 : 0

  role       = aws_iam_role.dd_forwarder.name
  policy_arn = format("arn:%s:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole", local.partition)
}

resource "aws_iam_role_policy" "dd_forwarder_secret" {
  name = "${local.dd_forwarder_function_name}-secret-access"
  role = aws_iam_role.dd_forwarder.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [{
        Sid      = "ReadDatadogApiKey"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [data.aws_secretsmanager_secret.dd_forwarder_api_key.arn]
      }],
      var.dd_api_key_kms_key_arn == null ? [] : [{
        Sid      = "DecryptDatadogApiKey"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = [var.dd_api_key_kms_key_arn]
      }]
    )
  })
}

# Created before the function so Lambda never creates it first (which would break the next apply).
resource "aws_cloudwatch_log_group" "dd_forwarder" {
  name              = local.dd_forwarder_log_group
  retention_in_days = var.dd_forwarder_log_retention_days
  tags              = merge(local.common_tags, { Name = local.dd_forwarder_function_name })
}

resource "aws_lambda_function" "dd_forwarder" {
  function_name = local.dd_forwarder_function_name
  description   = "Forwards ${var.application} ${var.environment_tag} CloudWatch logs to Datadog"
  role          = aws_iam_role.dd_forwarder.arn
  runtime       = "python3.14"
  handler       = "lambda_function.lambda_handler"
  architectures = ["arm64"]

  filename         = data.archive_file.dd_forwarder_placeholder.output_path
  source_code_hash = data.archive_file.dd_forwarder_placeholder.output_base64sha256
  layers           = [local.dd_forwarder_layer_arn]

  memory_size                    = var.dd_forwarder_memory_size
  timeout                        = var.dd_forwarder_timeout
  reserved_concurrent_executions = var.dd_forwarder_reserved_concurrency

  dynamic "vpc_config" {
    for_each = local.in_vpc ? [1] : []
    content {
      subnet_ids         = var.dd_forwarder_subnet_ids
      security_group_ids = var.dd_forwarder_security_group_ids
    }
  }

  environment {
    variables = { for k, v in local.dd_forwarder_environment : k => v if v != null }
  }

  depends_on = [
    aws_iam_role_policy_attachment.dd_forwarder_basic,
    aws_iam_role_policy_attachment.dd_forwarder_vpc,
    aws_iam_role_policy.dd_forwarder_secret,
    aws_cloudwatch_log_group.dd_forwarder,
  ]

  tags = merge(local.common_tags, { Name = local.dd_forwarder_function_name })
}

resource "aws_lambda_permission" "dd_forwarder_cloudwatch" {
  statement_id   = "CloudWatchLogsInvokePermission"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.dd_forwarder.function_name
  principal      = "logs.amazonaws.com"
  source_account = local.account_id
  source_arn = format(
    "arn:%s:logs:%s:%s:log-group:*:*",
    local.partition,
    var.region,
    local.account_id
  )
}

resource "aws_cloudwatch_log_subscription_filter" "dd_forwarder" {
  for_each = local.dd_forwarder_target_log_groups

  name            = var.subscription_filter_name
  log_group_name  = each.value
  filter_pattern  = lookup(var.filter_pattern_overrides, each.value, var.filter_pattern)
  destination_arn = aws_lambda_function.dd_forwarder.arn

  depends_on = [aws_lambda_permission.dd_forwarder_cloudwatch]
}
