include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/terragrunt/modules/alerts-sns"
}

inputs = {
  topic_name       = "security-alerts"
  email_param_name = "/infra/alert_email"

  extra_topic_policy_statements = [
    {
      sid                   = "AllowCloudWatchAlarmsPublish"
      actions               = ["sns:Publish"]
      principal_type        = "Service"
      principal_identifiers = ["cloudwatch.amazonaws.com"]
    }
  ]
}
