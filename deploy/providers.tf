provider "aws" {
  region = var.aws_region

  # Refuses to run if the credentials belong to a different account,
  # so prod settings can never be applied to dev (or the other way round).
  allowed_account_ids = [var.aws_account_id]

  dynamic "assume_role" {
    for_each = var.assume_role_arn == null ? [] : [var.assume_role_arn]
    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = merge({
      Application = "perkins"
      Environment = var.environment_tag
      ManagedBy   = "terraform"
      Purpose     = "datadog-log-forwarding"
    }, var.tags)
  }
}
