locals {
  computed_bucket_name = coalesce(
    var.bucket_name,
    "${var.bucket_prefix}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  )
}

# Log bucket (secure baseline + CloudTrail write policy)
module "log_bucket" {
  source = "../secure-s3-bucket"

  bucket_name   = local.computed_bucket_name
  force_destroy = var.force_destroy_bucket

  enable_versioning = true
  enable_tls_deny   = true

  # Add CloudTrail write policy on top of TLS deny
  extra_bucket_policy_json = data.aws_iam_policy_document.cloudtrail_bucket.json
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid = "AWSCloudTrailAclCheck20150319"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["s3:GetBucketAcl"]
    resources = [module.log_bucket.bucket_arn]

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

    resources = [
      "${module.log_bucket.bucket_arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${var.trail_name}"
      ]
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = var.log_group_name
  retention_in_days = var.retention_in_days
}

data "aws_iam_policy_document" "cloudtrail_to_cw_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cloudtrail_to_cw" {
  name               = "${var.trail_name}-to-cloudwatch-logs"
  assume_role_policy = data.aws_iam_policy_document.cloudtrail_to_cw_assume.json
}

data "aws_iam_policy_document" "cloudtrail_to_cw" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.this.arn}:*"
    ]
  }
}

resource "aws_iam_role_policy" "cloudtrail_to_cw" {
  name   = "${var.trail_name}-to-cloudwatch-logs"
  role   = aws_iam_role.cloudtrail_to_cw.id
  policy = data.aws_iam_policy_document.cloudtrail_to_cw.json
}

# NOTE:
# This SNS topic has no subscribers now. It's just in case.
# Actionable security alerts are handled via CloudWatch Logs metric alarms,
# not CloudTrail delivery notifications.
resource "aws_sns_topic" "this" {
  count             = var.enable_sns_notifications ? 1 : 0
  name              = var.sns_topic_name
  kms_master_key_id = "alias/aws/sns"
}

data "aws_iam_policy_document" "cloudtrail_sns" {
  count = var.enable_sns_notifications ? 1 : 0

  statement {
    sid    = "AWSCloudTrailPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.this[0].arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:cloudtrail:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:trail/${var.trail_name}"
      ]
    }
  }
}

resource "aws_sns_topic_policy" "this" {
  count  = var.enable_sns_notifications ? 1 : 0
  arn    = aws_sns_topic.this[0].arn
  policy = data.aws_iam_policy_document.cloudtrail_sns[0].json
}

resource "aws_cloudtrail" "this" {
  name                          = var.trail_name
  s3_bucket_name                = module.log_bucket.bucket_name
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  is_organization_trail         = false

  sns_topic_name = var.enable_sns_notifications ? aws_sns_topic.this[0].name : null

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.this.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_to_cw.arn

  depends_on = [
    aws_iam_role_policy.cloudtrail_to_cw,
    aws_sns_topic_policy.this,
    module.log_bucket,
  ]
}
