# Exception register as code (docs/03, section 3.4).
# Every exception to a platform rule is a row in register.json with an end date.
# The checks are output preconditions: a failed precondition is an error
# (Terraform Docs, "output block reference" and "Validate your infrastructure in
# Terraform's configuration language").

variable "register_json" {
  description = "The exception register as JSON text: {\"exceptions\": [ ... ]}."
  type        = string

  validation {
    condition     = can(jsondecode(var.register_json).exceptions)
    error_message = "The register must be JSON with an \"exceptions\" list."
  }
}

variable "today" {
  description = "Time used to decide if an exception has expired, as an RFC 3339 timestamp such as 2026-11-05T00:00:00Z. Leave it null to use the time of the plan."
  type        = string
  default     = null

  validation {
    condition     = var.today == null || can(timecmp(var.today, var.today))
    error_message = "The today value must be an RFC 3339 timestamp, for example 2026-11-05T00:00:00Z."
  }
}
