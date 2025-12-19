resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "GuardDutyFindingsToSNS"
  description = "Route selected GuardDuty findings to SNS"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [
        { numeric = [">=", var.min_severity] }
      ]
    }
  })
}


resource "aws_cloudwatch_event_target" "to_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToSNS"
  arn       = var.sns_topic_arn
}
