include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "alerts_sns" {
  config_path = "../alerts-sns"

  mock_outputs = {
    topic_arn = "arn:aws:sns:us-east-2:000000000000:security-alerts"
  }
  mock_outputs_allowed_terraform_commands = ["init", "plan", "validate"]
}

terraform {
  source = "${get_repo_root()}/infra/terragrunt/modules/guardduty-crypto-autokill"
}

inputs = {
  sns_topic_arn  = dependency.alerts_sns.outputs.topic_arn
  function_name  = "guardduty-crypto-autokill"
  stop_instances = true

  finding_type_prefixes = [
    "CryptoCurrency:EC2/"
  ]
}
