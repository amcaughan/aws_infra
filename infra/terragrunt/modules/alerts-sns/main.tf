resource "aws_sns_topic" "this" {
  name              = var.topic_name
  kms_master_key_id = "alias/aws/sns"
}

data "aws_ssm_parameter" "email" {
  name = var.email_param_name
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = trimspace(data.aws_ssm_parameter.email.value)
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "topic_policy" {
  # Explicitly allow account owner full control
  statement {
    sid    = "AllowOwnerAllActions"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions   = ["sns:*"]
    resources = [aws_sns_topic.this.arn]
  }

  dynamic "statement" {
    for_each = var.extra_topic_policy_statements
    content {
      sid    = statement.value.sid
      effect = statement.value.effect

      principals {
        type        = statement.value.principal_type
        identifiers = statement.value.principal_identifiers
      }

      actions   = statement.value.actions
      resources = [aws_sns_topic.this.arn]

      dynamic "condition" {
        for_each = statement.value.conditions
        content {
          test     = condition.value.test
          variable = condition.value.variable
          values   = condition.value.values
        }
      }
    }
  }
}

resource "aws_sns_topic_policy" "this" {
  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.topic_policy.json
}
