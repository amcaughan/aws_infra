#!/usr/bin/env bash
set -euo pipefail

# Edit these
REGION="us-east-2"
PROFILE="default"
BUCKET_NAME="amcaughan-tf-state-us-east-2" 

# Helpers
echo_hdr() {
  echo
  echo "===> $*"
}

aws_cmd() {
  aws --region "$REGION" --profile "$PROFILE" "$@"
}

# Email setup
# --- Alert email → SSM Parameter Store (for SNS subscriptions / budgets) ---
SSM_ALERT_EMAIL_PARAM="/infra/alert_email"

ensure_alert_email_param() {
  echo_hdr "Ensuring SSM parameter exists: $SSM_ALERT_EMAIL_PARAM"

  if [[ -z "${ALERT_EMAIL:-}" ]]; then
    echo "ERROR: ALERT_EMAIL env var is not set."
    echo "Set it like: export ALERT_EMAIL=\"you@example.com\""
    exit 1
  fi

  # Minimal sanity check (not perfect, but avoids obvious garbage)
  if [[ "$ALERT_EMAIL" != *"@"* || "$ALERT_EMAIL" != *"."* ]]; then
    echo "ERROR: ALERT_EMAIL does not look like an email address: $ALERT_EMAIL"
    exit 1
  fi

  # Write/overwrite the parameter (String is fine; not actually secret)
  aws_cmd ssm put-parameter \
    --name "$SSM_ALERT_EMAIL_PARAM" \
    --type "String" \
    --value "$ALERT_EMAIL" \
    --overwrite >/dev/null

  echo "SSM parameter set: $SSM_ALERT_EMAIL_PARAM"
}

ensure_alert_email_param


# State Bucket
echo_hdr "Checking S3 bucket: $BUCKET_NAME"

if aws_cmd s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
  echo "Bucket already exists: $BUCKET_NAME"
else
  echo "Bucket does not exist. Creating..."

  if [ "$REGION" = "us-east-1" ]; then
    aws_cmd s3api create-bucket \
      --bucket "$BUCKET_NAME"
  else
    aws_cmd s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi

  echo "Bucket created: $BUCKET_NAME"
fi

echo_hdr "Enabling versioning on bucket: $BUCKET_NAME"
aws_cmd s3api put-bucket-versioning \
  --bucket "$BUCKET_NAME" \
  --versioning-configuration Status=Enabled

echo_hdr "Enabling default encryption (SSE-S3) on bucket: $BUCKET_NAME"
aws_cmd s3api put-bucket-encryption \
  --bucket "$BUCKET_NAME" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" }
    }]
  }'

echo_hdr "Blocking public access for bucket: $BUCKET_NAME"
aws_cmd s3api put-public-access-block \
  --bucket "$BUCKET_NAME" \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

bucket_policy_exists() {
  aws_cmd s3api get-bucket-policy --bucket "$BUCKET_NAME" >/dev/null 2>&1
}

echo_hdr "Enforcing BucketOwnerEnforced (disable ACLs) on bucket: $BUCKET_NAME"
aws_cmd s3api put-bucket-ownership-controls \
  --bucket "$BUCKET_NAME" \
  --ownership-controls '{
    "Rules": [{"ObjectOwnership":"BucketOwnerEnforced"}]
  }'

echo_hdr "Ensuring TLS-only bucket policy exists on bucket: $BUCKET_NAME"

if bucket_policy_exists; then
  echo "Bucket policy already exists; not overwriting."
else
  echo_hdr "Enforcing TLS-only bucket policy on bucket: $BUCKET_NAME"
  POLICY_FILE="$(mktemp)"
  cat >"$POLICY_FILE" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::$BUCKET_NAME",
        "arn:aws:s3:::$BUCKET_NAME/*"
      ],
      "Condition": {
        "Bool": { "aws:SecureTransport": "false" }
      }
    }
  ]
}
EOF

  aws_cmd s3api put-bucket-policy \
    --bucket "$BUCKET_NAME" \
    --policy "file://$POLICY_FILE"

  rm -f "$POLICY_FILE"
fi

echo_hdr "Tagging bucket: $BUCKET_NAME"
aws_cmd s3api put-bucket-tagging \
  --bucket "$BUCKET_NAME" \
  --tagging '{
    "TagSet": [
      {"Key":"Project","Value":"aws_infra_core"},
      {"Key":"ManagedBy","Value":"bootstrap"}
    ]
  }'


echo_hdr "Done."
echo_hdr "  alert_email_ssm_param = \"$SSM_ALERT_EMAIL_PARAM\""
echo "Use these values in your Terragrunt root config:"
echo "  bucket         = \"$BUCKET_NAME\""
echo "  region         = \"$REGION\""
echo
echo "Example remote_state block:"
cat <<EOF
remote_state {
  backend = "s3"
  config = {
    bucket         = "$BUCKET_NAME"
    key            = "\${path_relative_to_include()}/terraform.tfstate"
    region         = "$REGION"
    use_lockfile   = true
    encrypt        = true
  }
}
EOF

cat <<EOF

============================================================
Terraform backend bootstrap complete
============================================================

This script created and/or enforced the following on the
Terraform state S3 bucket:

  - S3 bucket:               $BUCKET_NAME
  - Region:                  $REGION
  - Block Public Access:     ENABLED
  - Bucket versioning:       ENABLED
  - Default encryption:      SSE-S3 (AES256)
  - Object ownership:        BucketOwnerEnforced (ACLs disabled)
  - Bucket policy:           TLS-only access enforced
  - Tags:
      Project   = aws_infra_core
      ManagedBy = bootstrap

This bootstrap exists only to allow Terraform/Terragrunt
to start safely. It is expected that Terraform will take
ownership of these resources after initialization.

------------------------------------------------------------
Next steps (recommended)
------------------------------------------------------------

1) Define Terraform resources for the state bucket, e.g.:

     - aws_s3_bucket
     - aws_s3_bucket_versioning
     - aws_s3_bucket_server_side_encryption_configuration
     - aws_s3_bucket_public_access_block
     - aws_s3_bucket_ownership_controls
     - aws_s3_bucket_policy

2) Import the existing bucket into Terraform state:

     terraform import aws_s3_bucket.tf_state $BUCKET_NAME
     terraform import aws_s3_bucket_versioning.tf_state $BUCKET_NAME
     terraform import aws_s3_bucket_server_side_encryption_configuration.tf_state $BUCKET_NAME
     terraform import aws_s3_bucket_public_access_block.tf_state $BUCKET_NAME
     terraform import aws_s3_bucket_ownership_controls.tf_state $BUCKET_NAME

   If you manage the bucket policy in Terraform:

     terraform import aws_s3_bucket_policy.tf_state $BUCKET_NAME

3) Run 'terraform plan' and adjust configuration until
   the plan is clean.

------------------------------------------------------------
Additional hardening to manage in Terraform (later)
------------------------------------------------------------

  - Restrict bucket access to specific IAM roles
    (e.g. CI role, admin role) via bucket policy.

  - Add or standardize tags (e.g. environment, owner,
    cost center) under Terraform management.

  - Optionally switch to SSE-KMS if you want tighter
    access control and auditing.

Once Terraform fully manages the bucket, this bootstrap
script should only be needed for new accounts.

============================================================

EOF
