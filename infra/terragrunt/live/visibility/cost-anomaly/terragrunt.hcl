include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "visibility_alerts_sns" {
  config_path = "../alerts-sns"

  mock_outputs = {
    topic_arn = "arn:aws:sns:us-east-2:000000000000:visibility-alerts"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

terraform {
  source = "${get_repo_root()}/infra/terragrunt/modules/cost-anomaly"
}

inputs = {
  sns_topic_arn          = dependency.visibility_alerts_sns.outputs.topic_arn
  absolute_threshold_usd = 10
  frequency              = "IMMEDIATE"

  monitor_name      = "ServiceCostAnomalyMonitor"
  subscription_name = "ServiceCostAnomalyAlerts"
}
