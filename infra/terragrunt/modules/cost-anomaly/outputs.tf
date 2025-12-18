output "monitor_arn" {
  value = aws_ce_anomaly_monitor.service.arn
}

output "subscription_arn" {
  value = aws_ce_anomaly_subscription.this.arn
}
