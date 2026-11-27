# Mocked plans: no AWS access needed. Run with `terraform test` (or `tofu test`).

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "673786334990" }
  }
  mock_data "aws_secretsmanager_secret" {
    defaults = { arn = "arn:aws:secretsmanager:us-east-1:673786334990:secret:datadog/api-key-AbCdEf" }
  }
  mock_data "aws_cloudwatch_log_groups" {
    defaults = { log_group_names = [] }
  }
  mock_resource "aws_iam_role" {
    defaults = { arn = "arn:aws:iam::673786334990:role/perkins-production-datadog-forwarder-role" }
  }
  mock_resource "aws_lambda_function" {
    defaults = { arn = "arn:aws:lambda:us-east-1:673786334990:function:perkins-production-datadog-forwarder" }
  }
}

mock_provider "archive" {
  mock_data "archive_file" {
    defaults = { output_base64sha256 = "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU=" }
  }
}

# Every prefix lookup returns these groups (including the Forwarder's own, which must be skipped).
override_data {
  target = data.aws_cloudwatch_log_groups.by_prefix
  values = { log_group_names = [
    "/aws/connect/gcralsp-production-connect",
    "/aws/lambda/gcralsp-production-connect-main",
    "/aws/lambda/perkins-production-datadog-forwarder",
    "/aws/lambda/skip-me",
  ] }
}

variables {
  environment_tag        = "production"
  region                 = "us-east-1"
  dd_api_key_secret_name = "datadog/api-key"
}

run "selects_names_and_prefixes_and_excludes" {
  command = plan
  variables {
    log_group_names          = ["/aws/ses/gcralsp-production"]
    log_group_name_prefixes  = ["/aws/", "/aws/lambda/"]
    exclude_log_group_names  = ["/aws/lambda/skip-me"]
    filter_pattern_overrides = { "/aws/connect/gcralsp-production-connect" = "ERROR" }
  }
  assert {
    condition = jsonencode(output.subscribed_log_groups) == jsonencode([
      "/aws/connect/gcralsp-production-connect",
      "/aws/lambda/gcralsp-production-connect-main",
      "/aws/ses/gcralsp-production",
    ])
    error_message = "Wrong log groups selected: ${jsonencode(output.subscribed_log_groups)}"
  }
  assert {
    condition     = aws_cloudwatch_log_subscription_filter.dd_forwarder["/aws/connect/gcralsp-production-connect"].filter_pattern == "ERROR"
    error_message = "Per-group filter override not applied"
  }
  assert {
    condition     = aws_cloudwatch_log_subscription_filter.dd_forwarder["/aws/ses/gcralsp-production"].filter_pattern == ""
    error_message = "Default filter pattern should forward everything"
  }
}

run "vpc_and_proxy_like_the_ecs_module" {
  command = plan
  variables {
    dd_forwarder_subnet_ids          = ["subnet-a", "subnet-b"]
    dd_forwarder_security_group_ids  = ["sg-1"]
    dd_proxy_https                   = "http://proxy.example.internal:3128"
    dd_proxy_no_proxy                = ["secretsmanager.us-east-1.amazonaws.com", "169.254.169.254"]
    dd_forwarder_skip_ssl_validation = true
  }
  assert {
    condition     = output.forwarder_layer_arn == "arn:aws:lambda:us-east-1:464622532012:layer:Datadog-Forwarder:119"
    error_message = "Unexpected layer ARN: ${output.forwarder_layer_arn}"
  }
  assert {
    condition     = aws_lambda_function.dd_forwarder.function_name == "perkins-production-datadog-forwarder"
    error_message = "Unexpected function name"
  }
  assert {
    condition = (
      aws_lambda_function.dd_forwarder.environment[0].variables["DD_USE_VPC"] == "true" &&
      aws_lambda_function.dd_forwarder.environment[0].variables["HTTPS_PROXY"] == "http://proxy.example.internal:3128" &&
      aws_lambda_function.dd_forwarder.environment[0].variables["HTTP_PROXY"] == "http://proxy.example.internal:3128" &&
      aws_lambda_function.dd_forwarder.environment[0].variables["NO_PROXY"] == "secretsmanager.us-east-1.amazonaws.com,169.254.169.254" &&
      aws_lambda_function.dd_forwarder.environment[0].variables["DD_SKIP_SSL_VALIDATION"] == "true" &&
      aws_lambda_function.dd_forwarder.environment[0].variables["DD_SITE"] == "ddog-gov.com" &&
      aws_lambda_function.dd_forwarder.environment[0].variables["DD_TAGS"] == "app:perkins,env:production"
    )
    error_message = "Forwarder environment does not match the ECS module pattern: ${jsonencode(aws_lambda_function.dd_forwarder.environment[0].variables)}"
  }
  assert {
    condition     = length(aws_lambda_function.dd_forwarder.vpc_config) == 1 && length(aws_iam_role_policy_attachment.dd_forwarder_vpc) == 1
    error_message = "Forwarder should run in the VPC with the VPC access policy"
  }
}

run "no_vpc_no_proxy" {
  command = plan
  assert {
    condition = (
      aws_lambda_function.dd_forwarder.environment[0].variables["DD_USE_VPC"] == "false" &&
      !contains(keys(aws_lambda_function.dd_forwarder.environment[0].variables), "HTTPS_PROXY") &&
      !contains(keys(aws_lambda_function.dd_forwarder.environment[0].variables), "NO_PROXY")
    )
    error_message = "Unset proxy settings should not appear in the environment"
  }
  assert {
    condition     = length(aws_lambda_function.dd_forwarder.vpc_config) == 0 && length(aws_iam_role_policy_attachment.dd_forwarder_vpc) == 0
    error_message = "Forwarder should not be in a VPC"
  }
}

run "govcloud_uses_datadogs_govcloud_layer" {
  command = plan
  variables {
    region = "us-gov-west-1"
  }
  override_data {
    target = data.aws_partition.dd_forwarder
    values = { partition = "aws-us-gov" }
  }
  assert {
    condition     = output.forwarder_layer_arn == "arn:aws-us-gov:lambda:us-gov-west-1:002406178527:layer:Datadog-Forwarder:119"
    error_message = "Unexpected GovCloud layer ARN: ${output.forwarder_layer_arn}"
  }
}

run "subnets_need_security_groups" {
  command = plan
  variables {
    dd_forwarder_subnet_ids = ["subnet-a"]
  }
  expect_failures = [var.dd_forwarder_security_group_ids]
}
