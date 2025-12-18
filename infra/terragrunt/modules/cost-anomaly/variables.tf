variable "sns_topic_arn" {
  type = string
}

variable "monitor_name" {
  type    = string
  default = "ServiceCostAnomalyMonitor"
}

variable "subscription_name" {
  type    = string
  default = "ServiceCostAnomalyAlerts"
}

# IMMEDIATE, DAILY, WEEKLY
variable "frequency" {
  type    = string
  default = "IMMEDIATE"
}

variable "absolute_threshold_usd" {
  type    = number
  default = 10
}
