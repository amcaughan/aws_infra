include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "cloudtrail" {
  config_path = "../cloudtrail"

  mock_outputs = {
    log_group_name = "/aws/cloudtrail/account-trail"
  }

  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

dependency "alerts_sns" {
  config_path = "../alerts-sns"

  mock_outputs = {
    topic_arn = "arn:aws:sns:us-east-2:000000000000:security-alerts"
  }

  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

terraform {
  source = "${get_repo_root()}/infra/terragrunt/modules/cloudtrail-alarms"
}

inputs = {
  log_group_name = dependency.cloudtrail.outputs.log_group_name
  sns_topic_arn  = dependency.alerts_sns.outputs.topic_arn

  period_seconds = 300
  eval_periods   = 1
}
