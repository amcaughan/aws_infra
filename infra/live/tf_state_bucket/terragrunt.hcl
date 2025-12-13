include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../../modules/tf_state_bucket"
}

inputs = {
  bucket_name = "amcaughan-tf-state-us-east-2"
  tags = {
    Project   = "aws_infra_core"
    ManagedBy = "terraform"
  }
}