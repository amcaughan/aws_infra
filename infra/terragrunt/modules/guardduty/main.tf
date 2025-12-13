resource "aws_guardduty_detector" "this" {
  enable = var.enable

  datasources {
    s3_logs {
      enable = var.enable_s3_logs
    }
  }
}
