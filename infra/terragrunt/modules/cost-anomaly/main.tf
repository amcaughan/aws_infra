provider "aws" {
  alias  = "ce"
  region = "us-east-1"
}

resource "aws_ce_anomaly_monitor" "service" {
  provider          = aws.ce
  name              = var.monitor_name
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "this" {
  provider         = aws.ce
  name             = var.subscription_name
  frequency        = var.frequency
  monitor_arn_list = [aws_ce_anomaly_monitor.service.arn]

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.absolute_threshold_usd)]
    }
  }

  subscriber {
    type    = "SNS"
    address = var.sns_topic_arn
  }
}
