# Policy-as-code check for the platform standards layer (docs/03, section 3.2 and 3.5).
# It uses the variable "validation" block, which fails with an error when a rule is broken
# (Terraform Docs, "Validate your infrastructure in Terraform's configuration language").
#
# Rules (our standards, not AWS rules):
#   R1  The document is JSON with Version "2012-10-17" and a non-empty Statement list.
#   R2  Every statement has a Sid, so a reviewer and an audit log can name it.
#   R3  No statement is "Allow" for Action "*": no all-powerful role (task constraint).
#   R4  An SCP (kind "scp") has only "Deny" statements: we use the deny-list style
#       (AWS Docs, "Service control policy examples").
variable "policy" {
  description = "The policy to check. kind is scp, iam or bucket. json is the policy document as text."
  type = object({
    kind = string
    json = string
  })

  validation {
    condition     = contains(["scp", "iam", "bucket"], var.policy.kind)
    error_message = "The policy kind must be scp, iam or bucket."
  }

  validation {
    condition = (
      can(jsondecode(var.policy.json).Version) &&
      try(jsondecode(var.policy.json).Version, "") == "2012-10-17" &&
      try(length(jsondecode(var.policy.json).Statement), 0) > 0
    )
    error_message = "R1: the policy must be JSON with Version 2012-10-17 and at least one Statement."
  }

  validation {
    condition = alltrue([
      for s in try(jsondecode(var.policy.json).Statement, []) : can(s.Sid)
    ])
    error_message = "R2: every statement must have a Sid."
  }

  validation {
    condition = alltrue([
      for s in try(jsondecode(var.policy.json).Statement, []) :
      !(s.Effect == "Allow" && contains(flatten([s.Action]), "*"))
    ])
    error_message = "R3: no statement may Allow Action \"*\" (no all-powerful role)."
  }

  validation {
    condition = var.policy.kind != "scp" || alltrue([
      for s in try(jsondecode(var.policy.json).Statement, []) : s.Effect == "Deny"
    ])
    error_message = "R4: an SCP in this platform has only Deny statements."
  }
}
