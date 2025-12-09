resource "aws_guardduty_detector" "this" {
  enable = true

  datasources {
    s3_logs {
      enable = true
    }
  }

  tags = merge(local.tags, {
    Name = "guardduty-detector"
  })
}