include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "alerts_sns" {
  config_path = "../alerts-sns"
}

terraform {
  source = "../../..//modules/guardduty-eventbridge"
}

inputs = {
  sns_topic_arn = dependency.alerts_sns.outputs.topic_arn
}
