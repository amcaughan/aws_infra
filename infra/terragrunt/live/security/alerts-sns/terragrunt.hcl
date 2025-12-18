include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/alerts-sns"
}

inputs = {
  topic_name       = "security-alerts"
  email_param_name = "/infra/alert_email"
}
