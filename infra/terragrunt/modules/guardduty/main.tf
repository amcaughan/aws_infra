resource "aws_guardduty_detector" "this" {
  enable = var.enable
}

resource "aws_guardduty_detector_feature" "s3_data_events" {
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  status      = var.enable_s3_logs ? "ENABLED" : "DISABLED"
}
