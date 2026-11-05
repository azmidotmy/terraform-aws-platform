output "statement_count" {
  description = "Number of statements in the checked policy."
  value       = length(jsondecode(var.policy.json).Statement)
}
