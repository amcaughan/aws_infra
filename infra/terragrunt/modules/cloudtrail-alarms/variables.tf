variable "log_group_name" {
  type = string
}

variable "sns_topic_arn" {
  type = string
}

variable "period_seconds" {
  type    = number
  default = 300
}

variable "eval_periods" {
  type    = number
  default = 1
}
