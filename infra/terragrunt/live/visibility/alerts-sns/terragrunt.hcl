include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/terragrunt/modules/alerts-sns"
}

inputs = {
  topic_name       = "visibility-alerts"
  email_param_name = "/infra/alert_email"

  publisher_statements = [
    # Cost Anomaly Detection -> SNS
    {
      sid                   = "AllowCostExplorerPublish"
      principal_type        = "Service"
      principal_identifiers = ["costalerts.amazonaws.com"]
      actions               = ["sns:Publish"]
    },

    # Budgets -> SNS
    {
      sid                   = "AllowBudgetsPublish"
      principal_type        = "Service"
      principal_identifiers = ["budgets.amazonaws.com"]
      actions               = ["sns:Publish"]
    },
  ]
}
