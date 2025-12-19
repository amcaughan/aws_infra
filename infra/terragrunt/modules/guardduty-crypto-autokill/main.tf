locals {
  # Build an EventBridge "or" list for type prefixes.
  type_prefix_patterns = [
    for p in var.finding_type_prefixes : { prefix = p }
  ]
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_event_rule" "guardduty_crypto" {
  name        = "${var.function_name}-rule"
  description = "Auto-stop instances on GuardDuty EC2 cryptomining findings and notify SNS"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      type = local.type_prefix_patterns
    }
  })
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

locals {
  # CloudWatch log group ARN pattern for this function
  lambda_log_group_arn = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.function_name}:*"

  # EC2 instance ARN pattern, scoped to this account+region
  instance_arn_pattern = "arn:aws:ec2:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:instance/*"
}

data "aws_iam_policy_document" "lambda_policy" {
  statement {
    sid    = "StopInstancesScoped"
    effect = "Allow"
    actions = [
      "ec2:StopInstances"
    ]
    resources = [local.instance_arn_pattern]
  }

  statement {
    sid    = "DescribeInstances"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "PublishToSNS"
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [var.sns_topic_arn]
  }

  statement {
    sid    = "WriteLogsScoped"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [local.lambda_log_group_arn]
  }

  statement {
    sid       = "CreateLogGroup"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.enable_dlq ? [1] : []
    content {
      sid       = "SendToDLQ"
      effect    = "Allow"
      actions   = ["sqs:SendMessage"]
      resources = [aws_sqs_queue.dlq[0].arn]
    }
  }
}

resource "aws_iam_role_policy" "lambda_inline" {
  name   = "${var.function_name}-policy"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_policy.json
}

# Optional DLQ
resource "aws_sqs_queue" "dlq" {
  count = var.enable_dlq ? 1 : 0
  name  = "${var.function_name}-dlq"

  kms_master_key_id = "alias/aws/sqs"
}

# Lambda code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda.zip"

  source {
    content  = file("${path.module}/lambda.py")
    filename = "lambda.py"
  }
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.lambda.arn
  handler       = "lambda.handler"
  runtime       = "python3.12"
  timeout       = 30

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Safety valve to limit blast radius
  reserved_concurrent_executions = var.reserved_concurrent_executions

  # Optional env var encryption (leave null to use default)
  kms_key_arn = var.kms_key_arn

  environment {
    variables = {
      SNS_TOPIC_ARN  = var.sns_topic_arn
      STOP_INSTANCES = var.stop_instances ? "true" : "false"
    }
  }

  dynamic "dead_letter_config" {
    for_each = var.enable_dlq ? [1] : []
    content {
      target_arn = aws_sqs_queue.dlq[0].arn
    }
  }

  depends_on = [aws_iam_role_policy.lambda_inline]
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_crypto.arn
}

resource "aws_cloudwatch_event_target" "to_lambda" {
  rule      = aws_cloudwatch_event_rule.guardduty_crypto.name
  target_id = "InvokeLambda"
  arn       = aws_lambda_function.this.arn
}
