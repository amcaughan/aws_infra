variable "topic_name" {
  type = string
}

variable "email_param_name" {
  type = string
}

# Extra statements expressed in Terraform-native shape.
variable "extra_topic_policy_statements" {
  type = list(object({
    sid     = string
    effect  = optional(string, "Allow")
    actions = list(string)

    principal_type        = string
    principal_identifiers = list(string)

    # Optional list of conditions, already in aws_iam_policy_document format
    conditions = optional(list(object({
      test     = string
      variable = string
      values   = list(string)
    })), [])
  }))
  default = []
}
