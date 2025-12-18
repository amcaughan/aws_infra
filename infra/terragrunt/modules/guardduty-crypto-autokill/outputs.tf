output "event_rule_arn" {
  value = aws_cloudwatch_event_rule.guardduty_crypto.arn
}

output "lambda_function_name" {
  value = aws_lambda_function.this.function_name
}
