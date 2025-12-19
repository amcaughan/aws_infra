include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/terragrunt/modules/alerts-sns"
}

inputs = {
  topic_name       = "security-alerts"
  email_param_name = "/infra/alert_email"

  publisher_statements = [
    # CloudTrail metric alarms -> SNS
    {
      sid                   = "AllowCloudWatchAlarmsPublish"
      principal_type        = "Service"
      principal_identifiers = ["cloudwatch.amazonaws.com"]
      actions               = ["sns:Publish"]
    },

    # GuardDuty -> EventBridge -> SNS
    {
      sid                   = "AllowEventBridgePublish"
      principal_type        = "Service"
      principal_identifiers = ["events.amazonaws.com"]
      actions               = ["sns:Publish"]
    },
  ]
}
