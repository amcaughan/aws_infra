variable "bucket_name" {
  type = string
}

variable "force_destroy" {
  type    = bool
  default = false
}

variable "noncurrent_version_expiration_days" {
  type    = number
  default = 30
}

variable "abort_incomplete_multipart_days" {
  type    = number
  default = 7
}

variable "enable_versioning" {
  type    = bool
  default = true
}

variable "enable_tls_deny" {
  type    = bool
  default = true
}

variable "extra_bucket_policy_json" {
  type    = string
  default = null
}
