# Rules (our standards):
#   E1  Every exception has the fields id, rule, scope, owner, reason, approved_by,
#       approved_on and expires, and both dates are RFC 3339 timestamps.
#   E2  approved_by is not the owner: nobody approves their own exception.
#   E3  expires is after approved_on and at most 90 days after it (2160 hours).
#   E4  No exception has expired: "No exception is permanent" (docs/03, 3.4).
#   E5  Every id is unique.
#
# Functions: timecmp, timeadd, plantimestamp, coalesce, try, alltrue
# (Terraform Docs, "Date and time functions" and the pages for each function).

locals {
  required_fields = ["id", "rule", "scope", "owner", "reason", "approved_by", "approved_on", "expires"]
  entries         = jsondecode(var.register_json).exceptions
  now             = coalesce(var.today, plantimestamp())
  max_duration    = "2160h"
}

output "check_fields" {
  description = "E1 passed."
  value       = true

  precondition {
    condition = alltrue([
      for e in local.entries : alltrue([for f in local.required_fields : contains(keys(e), f)])
      ]) && alltrue([
      for e in local.entries : alltrue([
        for f in ["approved_on", "expires"] : try(can(timecmp(e[f], e[f])), false)
      ])
    ])
    error_message = "E1: every exception needs id, rule, scope, owner, reason, approved_by, approved_on and expires, with RFC 3339 dates."
  }
}

output "check_approval" {
  description = "E2 passed."
  value       = true

  precondition {
    condition     = alltrue([for e in local.entries : try(e.approved_by != e.owner, true)])
    error_message = "E2: approved_by must not be the owner."
  }
}

output "check_duration" {
  description = "E3 passed."
  value       = true

  precondition {
    condition = alltrue([
      for e in local.entries : try(
        timecmp(e.expires, e.approved_on) > 0 && timecmp(e.expires, timeadd(e.approved_on, local.max_duration)) <= 0,
        true
      )
    ])
    error_message = "E3: expires must be after approved_on and at most 90 days (2160h) after it."
  }
}

output "check_not_expired" {
  description = "E4 passed."
  value       = true

  precondition {
    condition     = alltrue([for e in local.entries : try(timecmp(e.expires, local.now) >= 0, true)])
    error_message = "E4: an exception has expired. Remove it, or renew it with a new review."
  }
}

output "check_unique_ids" {
  description = "E5 passed."
  value       = true

  precondition {
    condition     = length(distinct([for e in local.entries : try(e.id, "")])) == length(local.entries)
    error_message = "E5: exception ids must be unique."
  }
}

output "exception_count" {
  description = "Number of exceptions in the register."
  value       = length(local.entries)
}
