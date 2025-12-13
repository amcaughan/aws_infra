output "trail_arn" {
  value = aws_cloudtrail.this.arn
}

output "bucket_name" {
  value = module.log_bucket.bucket_name
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.this.name
}
