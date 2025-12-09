#!/usr/bin/env bash
set -euo pipefail

# Edit these
REGION="us-east-2"
PROFILE="default"
BUCKET_NAME="amcaughan-tf-state-us-east-2" 
TABLE_NAME="amcaughan-terraform-locks"

# Helpers
echo_hdr() {
  echo
  echo "===> $*"
}

aws_cmd() {
  aws --region "$REGION" --profile "$PROFILE" "$@"
}


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

# DynamoDB locks table for state locks
echo_hdr "Checking DynamoDB table: $TABLE_NAME"

if aws_cmd dynamodb describe-table --table-name "$TABLE_NAME" >/dev/null 2>&1; then
  echo "Table already exists: $TABLE_NAME"
else
  echo "Table does not exist. Creating..."

  aws_cmd dynamodb create-table \
    --table-name "$TABLE_NAME" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --tags Key=Project,Value=aws-infra Key=Managed,Value=terraform-locks

  echo "Waiting for table to become ACTIVE..."
  aws_cmd dynamodb wait table-exists --table-name "$TABLE_NAME"

  echo "Table created: $TABLE_NAME"
fi

echo_hdr "Done."

echo "Use these values in your Terragrunt root config:"
echo "  bucket         = \"$BUCKET_NAME\""
echo "  region         = \"$REGION\""
echo "  dynamodb_table = \"$TABLE_NAME\""
echo
echo "Example remote_state block:"
cat <<EOF
remote_state {
  backend = "s3"
  config = {
    bucket         = "$BUCKET_NAME"
    key            = "\${path_relative_to_include()}/terraform.tfstate"
    region         = "$REGION"
    dynamodb_table = "$TABLE_NAME"
    encrypt        = true
  }
}
EOF
