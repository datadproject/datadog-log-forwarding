# Perkins production — AWS account 673786334990
environment_tag = "production"
aws_account_id  = "673786334990"
aws_region      = "us-east-1"

# ---- Datadog API key ----------------------------------------------------------
# Name of the plain-text Secrets Manager secret in account 673786334990.
dd_api_key_secret_name = "REPLACE_WITH_SECRET_NAME"
# dd_api_key_kms_key_arn = "arn:aws:kms:us-east-1:673786334990:key/..." # only if the secret uses a customer KMS key

# ---- Network: Forwarder runs in the VPC and reaches Datadog through the proxy ---
dd_forwarder_subnet_ids          = ["REPLACE_WITH_PRIVATE_SUBNET_ID_A", "REPLACE_WITH_PRIVATE_SUBNET_ID_B"]
dd_forwarder_security_group_ids  = ["REPLACE_WITH_SECURITY_GROUP_ID"]
dd_proxy_https                   = "REPLACE_WITH_PROXY_URL" # proxy the Perkins VPC uses to reach the internet
dd_proxy_no_proxy                = []
dd_forwarder_skip_ssl_validation = true # Datadog's guidance when sending through a proxy

# ---- What to forward ----------------------------------------------------------
# Every log group starting with one of these prefixes is forwarded.
# They match whatever exists in this account, so the same list works in every environment.
log_group_name_prefixes = [
  "/aws/connect/",        # Amazon Connect contact flow logs
  "/aws/ses/",            # SES logs
  "/aws/vendedlogs/nlb/", # NLB access logs (the ELB-equivalent logs)
  "/aws/lambda/gcralsp-", # Perkins Lambda functions (Connect autodialer, main, response, Aurora rotation)
]

# Exact names for anything else, for example:
#   "/aws/rds/cluster/<aurora cluster>/postgresql",
#   "/aws/eks/<cluster name>/cluster",
log_group_names = []

# Log groups to leave out even if a prefix matches them.
exclude_log_group_names = []
