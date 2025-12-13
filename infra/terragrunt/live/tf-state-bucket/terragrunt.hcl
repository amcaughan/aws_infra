include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "../..//modules/tf-state-bucket"
}

inputs = {
  bucket_name = "amcaughan-tf-state-us-east-2"
  noncurrent_version_expiration_days = 30
  abort_incomplete_multipart_days    = 7
}
