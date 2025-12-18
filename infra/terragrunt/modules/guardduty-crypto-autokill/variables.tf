variable "sns_topic_arn" {
  type = string
}

variable "function_name" {
  type    = string
  default = "guardduty-crypto-autokill"
}

variable "stop_instances" {
  type    = bool
  default = true
}

# Match prefixes against GuardDuty finding "type"
variable "finding_type_prefixes" {
  type    = list(string)
  default = ["CryptoCurrency:EC2/"]
}
