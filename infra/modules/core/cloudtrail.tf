# Cloudtrail
resource "aws_cloudtrail" "main" {
  name                          = "account-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  is_organization_trail         = false

  tags = merge(local.tags, {
    Name = "account-trail"
  })

  depends_on = [
    aws_s3_bucket_policy.cloudtrail
  ]
}


# CloudTrail log bucket
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "cloudtrail-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  force_destroy = false

  tags = merge(local.tags, {
    Name = "cloudtrail-logs"
  })
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket                  = aws_s3_bucket.cloudtrail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  versioning_configuration {
    status = "Enabled"
  }
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid = "AWSCloudTrailAclCheck20150319"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.cloudtrail.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid = "AWSCloudTrailWrite20150319"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions = ["s3:PutObject"]

    # CloudTrail writes under this prefix
    resources = [
      "${aws_s3_bucket.cloudtrail.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    # CloudTrail must write with this ACL
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    # Lock to your account
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [
        "arn:aws:cloudtrail:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:trail/account-trail"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id
  policy = data.aws_iam_policy_document.cloudtrail_bucket.json
}
