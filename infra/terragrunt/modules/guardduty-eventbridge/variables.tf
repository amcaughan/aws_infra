variable "sns_topic_arn" {
  type = string
}

variable "min_severity" {
  type        = number
  description = "Only forward findings with severity >= this value. Set to 0 to disable filtering."
  default     = 7
}