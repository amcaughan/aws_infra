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
