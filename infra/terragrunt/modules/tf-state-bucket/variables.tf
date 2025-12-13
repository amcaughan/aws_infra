variable "bucket_name" {
  type = string
}

variable "noncurrent_version_expiration_days" {
  type    = number
  default = 30
}

variable "abort_incomplete_multipart_days" {
  type    = number
  default = 7
}
