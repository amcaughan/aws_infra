include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/infra/terragrunt/modules/guardduty"
}

inputs = {
  enable         = true
  enable_s3_logs = false
}
