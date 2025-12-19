include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/terragrunt//modules/cloudtrail"
}

inputs = {
  trail_name        = "account-trail"
  log_group_name    = "/aws/cloudtrail/account-trail"
  retention_in_days = 30

  bucket_name          = null # default
  bucket_prefix        = "cloudtrail-logs"
  force_destroy_bucket = false

  enable_sns_notifications = true
  sns_topic_name           = "cloudtrail-log-delivery"
}
