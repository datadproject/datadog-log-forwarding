# Perkins → Datadog log forwarding (Terraform)

Ships CloudWatch Logs from the Perkins AWS accounts (us-east-1) to Datadog (ddog-gov.com), using the
same Forwarder pattern as `ngdc-ecs-cluster-module/datadog-forward.tf`: Lambda with Datadog's
Forwarder layer, inside the VPC, out through the proxy, API key read from Secrets Manager. No
downloads at plan time. On top of that, any log group can be forwarded by exact name or by prefix.
The module also works in GovCloud: it picks Datadog's GovCloud layer automatically there.

```
modules/datadog-log-forwarding/   the module (Forwarder + subscriptions)
deploy/                           root config, one run per environment
deploy/envs/<env>.tfvars          settings and log groups for that environment
deploy/envs/<env>.s3.tfbackend    where that environment's state lives
```

| Environment | AWS account  | env tag on logs | Forwarder name |
|-------------|--------------|-----------------|----------------|
| dev         | 199570264848 | development     | perkins-development-datadog-forwarder |
| test        | 426674444186 | test            | perkins-test-datadog-forwarder |
| prod        | 673786334990 | production      | perkins-production-datadog-forwarder |

## Fill in before the first run (in each `envs/<env>.tfvars`)

| Setting | What to put |
|---------|-------------|
| `dd_api_key_secret_name` | Name of the plain-text Secrets Manager secret with the Datadog API key in that account |
| `dd_forwarder_subnet_ids` | Private subnets with a route to the proxy |
| `dd_forwarder_security_group_ids` | Security group allowing outbound HTTPS to the proxy |
| `dd_proxy_https` | Proxy URL the Perkins VPC uses to reach the internet |
| `dd_proxy_no_proxy` | Hosts that skip the proxy (for example VPC endpoint hostnames) |

And the state bucket in `envs/<env>.s3.tfbackend`.

If an account has no API key secret yet:
```sh
aws secretsmanager create-secret --region us-east-1 \
  --name datadog/api-key --secret-string '<DATADOG_API_KEY>'
```

## Deploy an environment

Run with credentials for that environment's account (or set `assume_role_arn`).
The provider refuses to run against any other account.

```sh
cd deploy
terraform init -reconfigure -backend-config=envs/dev.s3.tfbackend
terraform plan  -var-file=envs/dev.tfvars
terraform apply -var-file=envs/dev.tfvars
```

Repeat with `test` and `prod`. The output `subscribed_log_groups` lists everything now forwarding.

## Choosing what to forward

In `envs/<env>.tfvars`:

- `log_group_name_prefixes`: every log group starting with a prefix. Defaults cover Amazon Connect
  (`/aws/connect/`), SES (`/aws/ses/`), NLB access logs (`/aws/vendedlogs/nlb/`) and the Perkins
  Lambdas (`/aws/lambda/gcralsp-`). They match whatever exists in the account, so the same list works
  in every environment.
- `log_group_names`: exact names for anything else (RDS, EKS control plane, ...). Plan fails if a
  name doesn't exist.
- `exclude_log_group_names`: groups to skip. The Forwarder's own log group is always skipped.
- `filter_pattern` / `filter_pattern_overrides`: forward only matching events (for example `ERROR`)
  to cut Datadog ingestion. Empty means everything.

Prefixes are evaluated at plan time; a log group created later is picked up on the next `apply`.

## Check it in Datadog

Log Explorer: `app:perkins env:production` (or `@aws.awslogs.logGroup:*gcralsp*`).
If nothing arrives, check the Forwarder's own log group `/aws/lambda/perkins-<env>-datadog-forwarder`
for proxy or API key errors.

## Things to know

- CloudWatch allows **2 subscription filters per log group**. If a group already has two (for
  example a landing-zone log shipper), apply fails for that group. Check the *Subscription filters*
  column in the CloudWatch console.
- Layer version defaults to **119**, the version in Datadog's current CloudFormation template.
- Logs stored only in S3 (ALB access logs, WAF logs written to S3) need an S3 trigger, not covered here.
- `terraform destroy` removes the Forwarder and every subscription it created.
