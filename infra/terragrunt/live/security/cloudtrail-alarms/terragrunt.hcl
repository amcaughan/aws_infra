include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "alerts_sns" {
  config_path = "../alerts-sns"
}

terraform {
  source = "../../..//modules/cloudtrail-alarms"
}

inputs = {
  log_group_name = "/aws/cloudtrail/account-trail"
  sns_topic_arn  = dependency.alerts_sns.outputs.topic_arn

  period_seconds = 300
  eval_periods   = 1
}
