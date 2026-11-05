variable "bucket_name" {
  description = "Name of the state bucket. Pattern: <prefix>-<virtual-account>-tfstate-<aws-account-id>-<region>."
  type        = string

  validation {
    condition     = length(var.bucket_name) >= 3 && length(var.bucket_name) <= 63
    error_message = "The bucket_name must be between 3 and 63 characters."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS key used for server-side encryption of the state."
  type        = string

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:kms:", var.kms_key_arn))
    error_message = "The kms_key_arn must be a KMS key ARN that starts with arn:aws:kms:."
  }
}

variable "tags" {
  description = "Tags applied to the bucket. Use the cost allocation tag keys agreed by the platform."
  type        = map(string)
  default     = {}
}
