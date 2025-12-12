locals {
  aws_region  = "us-east-2"
  aws_profile = "default"

  common_tags = {
    Project = "aws-infra"
    Owner   = "amcaughan"
    Env     = "personal"
    Managed = "terragrunt"
  }
}

# These can be created by bootstrap if they don't exist already
remote_state {
  backend = "s3"

  config = {
    bucket         = "amcaughan-tf-state-us-east-2"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    use_lockfile   = true
    encrypt        = true
  }
}

# Make root inputs available to all stacks
inputs = {
  common_tags = local.common_tags
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region  = "${local.aws_region}"
  profile = "${local.aws_profile}"
}
EOF
}
