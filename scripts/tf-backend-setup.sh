#!/usr/bin/env bash
set -euo pipefail

# Config
REGION="us-east-2"
PROFILE="default"
BUCKET_NAME="amcaughan-tf-state-us-east-2"

# Alert email (for SNS subscriptions / budgets / whatever)
SSM_ALERT_EMAIL_PARAM="/infra/alert_email"

# Lifecycle defaults (for tf state bucket)
NONCURRENT_EXPIRE_DAYS=30
ABORT_MULTIPART_DAYS=7

# Helpers
echo_hdr() {
  echo
  echo "===> $*"
}

aws_cmd() {
  aws --region "$REGION" --profile "$PROFILE" "$@"
}

retry() {
  local attempts="$1"; shift
  local n=1
  until "$@"; do
    if (( n >= attempts )); then
      return 1
    fi
    sleep $(( n * 2 ))
    n=$(( n + 1 ))
  done
}

require_aws_cli() {
  if ! command -v aws >/dev/null 2>&1; then
    echo "ERROR: aws CLI not found. Install AWS CLI v2 and retry."
    exit 1
  fi
}

# Email parameter
ensure_alert_email_param() {
  echo_hdr "Ensuring SSM parameter exists: $SSM_ALERT_EMAIL_PARAM"

  if [[ -z "${ALERT_EMAIL:-}" ]]; then
    echo "ERROR: ALERT_EMAIL env var is not set."
    echo "Set it like: export ALERT_EMAIL=\"you@example.com\""
    exit 1
  fi

  if [[ "$ALERT_EMAIL" != *"@"* || "$ALERT_EMAIL" != *"."* ]]; then
    echo "ERROR: ALERT_EMAIL does not look like an email address: $ALERT_EMAIL"
    exit 1
  fi

  aws_cmd ssm put-parameter \
    --name "$SSM_ALERT_EMAIL_PARAM" \
    --type "String" \
    --value "$ALERT_EMAIL" \
    --overwrite >/dev/null

  echo "SSM parameter set: $SSM_ALERT_EMAIL_PARAM"
}

# State Bucket
ensure_state_bucket() {
  echo_hdr "Checking S3 bucket: $BUCKET_NAME"

  if aws_cmd s3api head-bucket --bucket "$BUCKET_NAME" 2>/dev/null; then
    echo "Bucket already exists: $BUCKET_NAME"
  else
    echo "Bucket does not exist. Creating..."

    if [ "$REGION" = "us-east-1" ]; then
      aws_cmd s3api create-bucket --bucket "$BUCKET_NAME"
    else
      aws_cmd s3api create-bucket \
        --bucket "$BUCKET_NAME" \
        --create-bucket-configuration LocationConstraint="$REGION"
    fi

    echo "Bucket created: $BUCKET_NAME"
  fi

  echo_hdr "Waiting for bucket to be reachable: $BUCKET_NAME"
  retry 6 aws_cmd s3api head-bucket --bucket "$BUCKET_NAME" >/dev/null

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

  echo_hdr "Enforcing BucketOwnerEnforced (disable ACLs) on bucket: $BUCKET_NAME"
  aws_cmd s3api put-bucket-ownership-controls \
    --bucket "$BUCKET_NAME" \
    --ownership-controls '{
      "Rules": [{"ObjectOwnership":"BucketOwnerEnforced"}]
    }'

  echo_hdr "Applying lifecycle rules on bucket: $BUCKET_NAME"
  LIFECYCLE_FILE="$(mktemp)"
  cat >"$LIFECYCLE_FILE" <<EOF
{
  "Rules": [
    {
      "ID": "expire-noncurrent-versions",
      "Status": "Enabled",
      "Filter": {},
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": $NONCURRENT_EXPIRE_DAYS
      }
    },
    {
      "ID": "abort-incomplete-multipart-uploads",
      "Status": "Enabled",
      "Filter": {},
      "AbortIncompleteMultipartUpload": {
        "DaysAfterInitiation": $ABORT_MULTIPART_DAYS
      }
    }
  ]
}
EOF

  aws_cmd s3api put-bucket-lifecycle-configuration \
    --bucket "$BUCKET_NAME" \
    --lifecycle-configuration "file://$LIFECYCLE_FILE"

  rm -f "$LIFECYCLE_FILE"

  echo_hdr "Enforcing TLS-only bucket policy on bucket: $BUCKET_NAME (overwrite)"
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

  echo_hdr "Tagging bucket: $BUCKET_NAME"
  aws_cmd s3api put-bucket-tagging \
    --bucket "$BUCKET_NAME" \
    --tagging '{
      "TagSet": [
        {"Key":"Project","Value":"aws_infra_core"},
        {"Key":"ManagedBy","Value":"bootstrap"}
      ]
    }'
}

# Main
require_aws_cli
ensure_alert_email_param
ensure_state_bucket

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
