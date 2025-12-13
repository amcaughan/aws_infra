include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/guardduty"
}

inputs = {
  enable        = true
  enable_s3_logs = true
}
