include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../../modules/access-analyzer"
}

inputs = {
  analyzer_name = "account-access-analyzer"
  type          = "ACCOUNT"
}