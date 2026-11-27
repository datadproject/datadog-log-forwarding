# datadog-log-forwarding

Datadog Forwarder Lambda for one AWS account and region, built the same way as
`ngdc-ecs-cluster-module/datadog-forward.tf` (Datadog Forwarder layer, python3.14 / arm64,
VPC + proxy, API key secret looked up by name), plus subscription of any CloudWatch log groups by
exact name and/or prefix. The layer comes from Datadog's account 464622532012 in commercial AWS and
002406178527 in GovCloud, chosen automatically from the partition.

```hcl
module "datadog_log_forwarding" {
  source = "../modules/datadog-log-forwarding"

  environment_tag        = "production"
  region                 = "us-east-1"
  dd_api_key_secret_name = "datadog/api-key"

  dd_forwarder_subnet_ids          = ["subnet-aaa", "subnet-bbb"]
  dd_forwarder_security_group_ids  = ["sg-123"]
  dd_proxy_https                   = "http://proxy.internal:3128"
  dd_forwarder_skip_ssl_validation = true

  log_group_name_prefixes = ["/aws/connect/", "/aws/ses/", "/aws/vendedlogs/nlb/", "/aws/lambda/gcralsp-"]
  log_group_names         = ["/aws/rds/cluster/gcralsp-production-aurora/postgresql"]
}
```

## Inputs

| Name | Default | Description |
|------|---------|-------------|
| `environment_tag` | required | Used in names; env tag on every forwarded log |
| `application` | `perkins` | Name prefix; app tag on every forwarded log |
| `region` | required | Region of the Forwarder and log groups |
| `dd_site` | `ddog-gov.com` | Datadog site |
| `dd_api_key_secret_name` | required | Plain-text secret with the API key |
| `dd_api_key_kms_key_arn` | `null` | Customer KMS key on the secret, if any |
| `dd_tags` | `{}` | Extra tags on every log |
| `dd_forwarder_layer_version` | `119` | Datadog Forwarder layer version |
| `dd_forwarder_memory_size` | `1024` | Memory (MB) |
| `dd_forwarder_timeout` | `120` | Timeout (s) |
| `dd_forwarder_reserved_concurrency` | `null` | Reserved concurrency |
| `dd_forwarder_log_retention_days` | `90` | Retention of the Forwarder's own logs |
| `dd_forwarder_subnet_ids` | `[]` | Run in these subnets (empty = no VPC) |
| `dd_forwarder_security_group_ids` | `[]` | Required with subnets |
| `dd_proxy_https` | `null` | Sets HTTP_PROXY / HTTPS_PROXY |
| `dd_proxy_no_proxy` | `[]` | Sets NO_PROXY |
| `dd_forwarder_skip_ssl_validation` | `false` | Datadog says true when using a proxy |
| `log_group_names` | `[]` | Exact log groups; plan fails on a missing one |
| `log_group_name_prefixes` | `[]` | Forward every group starting with these |
| `exclude_log_group_names` | `[]` | Groups to skip |
| `filter_pattern` | `""` | Filter for all groups; empty forwards everything |
| `filter_pattern_overrides` | `{}` | Per-group filter, keyed by log group name |
| `subscription_filter_name` | `datadog-forwarder` | Name of each subscription filter |
| `tags` | `{}` | AWS tags |

## Outputs

`forwarder_arn`, `forwarder_function_name`, `forwarder_role_arn`, `forwarder_layer_arn`,
`subscribed_log_groups`.

## Tests

`terraform test` runs mocked plans (no AWS access): log group selection and exclusions, per-group
filters, VPC + proxy environment matching the ECS module, no-VPC mode, commercial vs GovCloud
layer, and input validation.
