variable "trail_name" {
  type = string
}

variable "log_group_name" {
  type = string
}

variable "retention_in_days" {
  type    = number
  default = 30
}

variable "bucket_name" {
  type    = string
  default = null
}

variable "bucket_prefix" {
  type    = string
  default = "cloudtrail-logs"
}

variable "force_destroy_bucket" {
  type    = bool
  default = false
}

variable "enable_sns_notifications" {
  type    = bool
  default = true
}

variable "sns_topic_name" {
  type    = string
  default = "cloudtrail-log-delivery"
}
