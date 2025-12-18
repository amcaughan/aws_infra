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

variable "finding_type_prefixes" {
  type    = list(string)
  default = ["CryptoCurrency:EC2/"]
}

variable "enable_dlq" {
  type    = bool
  default = true
}

variable "reserved_concurrent_executions" {
  type    = number
  default = 2
}

# Optional KMS key for environment variable encryption (null = provider default)
variable "kms_key_arn" {
  type    = string
  default = null
}
