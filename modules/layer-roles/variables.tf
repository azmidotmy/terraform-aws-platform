variable "virtual_account" {
  description = "Virtual account that owns the layer: platform, nonprod or prod."
  type        = string

  validation {
    condition     = contains(["platform", "nonprod", "prod"], var.virtual_account)
    error_message = "The virtual_account must be platform, nonprod or prod."
  }
}

variable "layer" {
  description = "Layer these roles serve: org, baseline, platform or workload."
  type        = string

  validation {
    condition     = contains(["org", "baseline", "platform", "workload"], var.layer)
    error_message = "The layer must be org, baseline, platform or workload."
  }
}

variable "codebuild_project_arns" {
  description = "ARNs of the CodeBuild projects allowed to assume each role. One project per role."
  type = object({
    plan  = string
    apply = string
  })

  validation {
    condition     = var.codebuild_project_arns.plan != var.codebuild_project_arns.apply
    error_message = "Plan and apply must use different CodeBuild projects."
  }
}

variable "state_bucket_arn" {
  description = "ARN of the state bucket of this virtual account."
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key that encrypts the state bucket."
  type        = string
}

variable "permissions_boundary_arn" {
  description = "ARN of the permissions boundary attached to the apply role."
  type        = string
}

variable "plan_policy_json" {
  description = "Optional extra policy for the plan role. Must contain read-only actions. The module cannot check this."
  type        = string
  default     = null

  validation {
    condition     = var.plan_policy_json == null || can(jsondecode(var.plan_policy_json))
    error_message = "The plan_policy_json must be valid JSON."
  }
}

variable "apply_policy_json" {
  description = "Policy with the resource permissions of this layer. Kept small: it is the only thing that lets the apply role change resources."
  type        = string

  validation {
    condition     = can(jsondecode(var.apply_policy_json))
    error_message = "The apply_policy_json must be valid JSON."
  }
}

variable "tags" {
  description = "Tags applied to both roles."
  type        = map(string)
  default     = {}
}
