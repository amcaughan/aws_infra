resource "aws_guardduty_detector" "this" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
  }

  tags = {
    Name = "guardduty-detector"
  }
}